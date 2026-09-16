import Foundation
import SwiftData
import ScanEngine

@MainActor
struct InventoryRepository {
    var context: ModelContext
    var merger: InventoryMerger

    init(context: ModelContext, merger: InventoryMerger = InventoryMerger()) {
        self.context = context
        self.merger = merger
    }

    func persistCompletedRun(
        configuration: ScanConfiguration,
        startedAt: Date,
        hosts: [HostDraft],
        summary: ScanSummary
    ) throws -> ScanRunRecord {
        let scope = try existingOrNewScope(configuration.scope)
        let run = ScanRunRecord(
            startedAt: startedAt,
            profile: configuration.profile,
            rateLimitPerSecond: configuration.rateLimitPerSecond
        )
        run.finishedAt = .now
        run.statusRaw = summary.status.rawValue
        run.scope = scope
        context.insert(run)

        var devices = try context.fetch(FetchDescriptor<DeviceRecord>())
        for host in hosts {
            let record = ScanHostRecord(draft: host)
            record.run = run
            let device = matchingDevice(for: host, among: devices) ?? newDevice(from: host)
            if !devices.contains(where: { $0.deviceID == device.deviceID }) {
                devices.append(device)
            }
            record.device = device
            device.lastSeenAt = .now
            device.ouiVendor = host.identity.vendor ?? device.ouiVendor
            context.insert(record)
        }

        try context.save()
        return run
    }

    func pruneRuns(olderThanDays days: Int) throws {
        guard days > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)
        let runs = try context.fetch(
            FetchDescriptor<ScanRunRecord>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        )
        var keptScope: Set<String> = []
        for run in runs {
            let key = "\(run.scope?.interfaceName ?? "")|\(run.scope?.cidr ?? "")"
            if keptScope.insert(key).inserted {
                continue
            }
            if run.startedAt < cutoff {
                context.delete(run)
            }
        }
        try context.save()
    }

    private func existingOrNewScope(_ draft: NetworkScopeDraft) throws -> NetworkScopeRecord {
        let interface = draft.interfaceName
        let cidr = draft.cidr
        var descriptor = FetchDescriptor<NetworkScopeRecord>(
            predicate: #Predicate { $0.interfaceName == interface && $0.cidr == cidr }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let created = NetworkScopeRecord(interfaceName: interface, cidr: cidr)
        context.insert(created)
        return created
    }

    private func matchingDevice(for host: HostDraft, among devices: [DeviceRecord]) -> DeviceRecord? {
        let snapshots = devices.map(\.snapshot)
        guard let id = merger.matchingDeviceID(for: host, in: snapshots) else { return nil }
        return devices.first { $0.deviceID == id }
    }

    func snapshots(interface: String, cidr: String, before: Date) throws -> [HostDriftSnapshot] {
        try matchingRun(interface: interface, cidr: cidr, before: before)?.hosts.map(\.driftSnapshot) ?? []
    }

    func latestSnapshots(interface: String, cidr: String) throws -> (startedAt: Date, hosts: [HostDriftSnapshot])? {
        guard let run = try matchingRun(interface: interface, cidr: cidr, before: .distantFuture) else {
            return nil
        }
        return (run.startedAt, run.hosts.map(\.driftSnapshot))
    }

    private func matchingRun(interface: String, cidr: String, before: Date) throws -> ScanRunRecord? {
        let descriptor = FetchDescriptor<ScanRunRecord>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let runs = try context.fetch(descriptor)
        return runs.first { run in
            run.scope?.interfaceName == interface
                && run.scope?.cidr == cidr
                && run.startedAt < before
        }
    }

    private func newDevice(from host: HostDraft) -> DeviceRecord {
        let device = DeviceRecord(
            primaryMAC: host.identity.mac.flatMap(MACAddress.init)?.canonical,
            displayName: host.identity.displayName
        )
        device.ouiVendor = host.identity.vendor
        context.insert(device)
        return device
    }
}
