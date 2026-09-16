import Foundation
import Observation
import ScanEngine
import ScanEngineMocks

@Observable
@MainActor
final class ScanController {
    var scopes: [NetworkScopeDraft] = []
    var selectedScopeID: String?
    var profile: ScanProfile = .standard
    var hosts: [HostDraft] = []
    var phase: ScanPhase?
    var progressCompleted = 0
    var progressTotal = 0
    var isRunning = false
    var lastError: String?
    var lastSummary: ScanSummary?
    var selectedHostID: UUID?
    var usesFixtureEngine = false
    var driftRows: [DriftRow] = []
    var schedule: ScanSchedule = .off {
        didSet {
            preferences.schedule = schedule
            if schedule != .off { ScanNotifier.requestAuthorization() }
            restartScheduler()
        }
    }
    var retentionDays: Int = 30 {
        didSet { preferences.retentionDays = retentionDays }
    }
    var hideIgnoredFindings: Bool = true {
        didSet { preferences.hideIgnoredFindings = hideIgnoredFindings }
    }
    var scanOnLaunch: Bool = false {
        didSet { preferences.scanOnLaunch = scanOnLaunch }
    }

    private let preferences = ScanPreferences()
    private var scheduleTask: Task<Void, Never>?
    private var startedBySchedule = false
    private let liveEngine: LiveScanEngine
    private let fixtureEngine: FakeScanEngine
    private let repository: InventoryRepository
    private let authorization: AuthorizationStore
    private var scanTask: Task<Void, Never>?
    private var runStartedAt: Date?

    init(
        repository: InventoryRepository,
        authorization: AuthorizationStore = AuthorizationStore(),
        liveEngine: LiveScanEngine = LiveScanEngine(),
        fixtureEngine: FakeScanEngine = FakeScanEngine()
    ) {
        self.liveEngine = liveEngine
        self.fixtureEngine = fixtureEngine
        self.repository = repository
        self.authorization = authorization
        self.schedule = preferences.schedule
        self.retentionDays = preferences.retentionDays
        self.hideIgnoredFindings = preferences.hideIgnoredFindings
        self.scanOnLaunch = preferences.scanOnLaunch
        restartScheduler()
    }

    private var engine: any ScanEngine {
        usesFixtureEngine ? fixtureEngine : liveEngine
    }

    var selectedScope: NetworkScopeDraft? {
        scopes.first { $0.id == selectedScopeID } ?? scopes.first
    }

    var selectedHost: HostDraft? {
        hosts.first { $0.id == selectedHostID }
    }

    var needsAuthorization: Bool {
        guard let selectedScope else { return true }
        return !authorization.isAuthorized(selectedScope)
    }

    var configuration: ScanConfiguration? {
        guard let selectedScope else { return nil }
        return ScanConfiguration(
            scope: selectedScope,
            profile: profile,
            credentials: CredentialVault().resolved()
        )
    }

    var findings: [FindingDraft] {
        let all = hosts.flatMap(\.findings)
        if hideIgnoredFindings {
            return all.filter { $0.status != .ignored }
        }
        return all
    }

    var currentReport: ScanReport? {
        guard let selectedScope else { return nil }
        return ScanReport(
            interfaceName: selectedScope.interfaceName,
            cidr: selectedScope.cidr,
            profile: profile.rawValue,
            summary: lastSummary,
            hosts: hosts
        )
    }

    func refreshDrift() {
        guard let selectedScope else {
            driftRows = []
            return
        }
        let interface = selectedScope.interfaceName
        let cidr = selectedScope.cidr
        if hosts.isEmpty {
            if let latest = try? repository.latestSnapshots(interface: interface, cidr: cidr) {
                let previous = (try? repository.snapshots(
                    interface: interface,
                    cidr: cidr,
                    before: latest.startedAt
                )) ?? []
                driftRows = InventoryDiffer.diff(previous: previous, current: latest.hosts)
            } else {
                driftRows = []
            }
        } else {
            let previous = (try? repository.snapshots(
                interface: interface,
                cidr: cidr,
                before: runStartedAt ?? .now
            )) ?? []
            driftRows = InventoryDiffer.diff(previous: previous, current: hosts.map(\.driftSnapshot))
        }
    }

    func refreshScopes() async {
        let list = await engine.availableScopes()
        scopes = list
        if selectedScopeID == nil {
            selectedScopeID = list.first(where: \.isAssessable)?.id ?? list.first?.id
        }
    }

    func authorizeSelectedScope() {
        guard let selectedScope else { return }
        authorization.authorize(selectedScope)
    }

    func setFindingStatus(_ id: UUID, _ status: FindingStatus) {
        for hostIndex in hosts.indices {
            if let findingIndex = hosts[hostIndex].findings.firstIndex(where: { $0.id == id }) {
                hosts[hostIndex].findings[findingIndex].status = status
            }
        }
    }

    func start(fromSchedule: Bool = false) {
        guard let configuration, !isRunning else { return }
        guard configuration.scope.isAssessable else {
            lastError = "This scope is not a private or link-local network."
            return
        }
        lastError = nil
        lastSummary = nil
        hosts = []
        selectedHostID = nil
        isRunning = true
        phase = .discovering
        progressCompleted = 0
        progressTotal = 0
        runStartedAt = .now
        startedBySchedule = fromSchedule
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            await self?.consume(configuration)
        }
    }

    func stop() {
        scanTask?.cancel()
        Task { await engine.cancel() }
    }

    private func consume(_ configuration: ScanConfiguration) async {
        let stream = await engine.events(for: configuration)
        for await event in stream {
            if Task.isCancelled { break }
            apply(event)
        }
        isRunning = false
        refreshDrift()
        if startedBySchedule, lastSummary?.status == .completed {
            let newCount = driftRows.filter { $0.status == .appeared }.count
            let highCount = findings.filter {
                $0.status == .open && $0.classification.severity >= .high
            }.count
            ScanNotifier.postCompletion(
                hostCount: hosts.count,
                newCount: newCount,
                highCount: highCount
            )
        }
    }

    private func apply(_ event: ScanEvent) {
        switch event {
        case .phaseChanged(let phase):
            self.phase = phase
        case .hostDiscovered(let host):
            upsert(host)
        case .hostUpdated(let host):
            upsert(host)
        case .progress(let completed, let total):
            progressCompleted = completed
            progressTotal = total
        case .completed(let summary):
            lastSummary = summary
            persist(summary)
        case .failed(let message):
            lastError = message
        case .cancelled:
            lastSummary = ScanSummary(hostCount: hosts.count, findingCount: findings.count, status: .cancelled)
        }
    }

    private func upsert(_ host: HostDraft) {
        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[index] = host
        } else {
            hosts.append(host)
        }
        if selectedHostID == nil {
            selectedHostID = host.id
        }
    }

    private func persist(_ summary: ScanSummary) {
        guard let configuration, let runStartedAt else { return }
        do {
            _ = try repository.persistCompletedRun(
                configuration: configuration,
                startedAt: runStartedAt,
                hosts: hosts,
                summary: summary
            )
            try repository.pruneRuns(olderThanDays: retentionDays)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func considerLaunchScan() {
        guard scanOnLaunch, !needsAuthorization, !isRunning else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard let self, !self.isRunning, !self.needsAuthorization else { return }
            self.start(fromSchedule: true)
        }
    }

    func restartScheduler() {
        scheduleTask?.cancel()
        guard let interval = schedule.interval else { return }
        scheduleTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self, !Task.isCancelled else { return }
                if self.isRunning || self.needsAuthorization { continue }
                self.start(fromSchedule: true)
            }
        }
    }
}
