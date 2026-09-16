import Foundation
import SwiftData
import ScanEngine

@Model
final class NetworkScopeRecord {
    var interfaceName: String
    var cidr: String
    var authorizationAcknowledgedAt: Date
    var authorizationTextVersion: String

    @Relationship(deleteRule: .cascade, inverse: \ScanRunRecord.scope)
    var runs: [ScanRunRecord]

    init(
        interfaceName: String,
        cidr: String,
        authorizationAcknowledgedAt: Date = .now,
        authorizationTextVersion: String = AuthorizationCopy.version
    ) {
        self.interfaceName = interfaceName
        self.cidr = cidr
        self.authorizationAcknowledgedAt = authorizationAcknowledgedAt
        self.authorizationTextVersion = authorizationTextVersion
        self.runs = []
    }
}

@Model
final class ScanRunRecord {
    var runID: UUID
    var startedAt: Date
    var finishedAt: Date?
    var statusRaw: String
    var profileRaw: String
    var rateLimitPerSecond: Int
    var engineVersion: String
    var cveSnapshotVersion: String
    var errorMessage: String?
    var scope: NetworkScopeRecord?

    @Relationship(deleteRule: .cascade, inverse: \ScanHostRecord.run)
    var hosts: [ScanHostRecord]

    init(
        runID: UUID = UUID(),
        startedAt: Date = .now,
        profile: ScanProfile,
        rateLimitPerSecond: Int
    ) {
        self.runID = runID
        self.startedAt = startedAt
        self.statusRaw = ScanStatus.running.rawValue
        self.profileRaw = profile.rawValue
        self.rateLimitPerSecond = rateLimitPerSecond
        self.engineVersion = "fixture-1"
        self.cveSnapshotVersion = "none"
        self.hosts = []
    }

    var status: ScanStatus {
        ScanStatus(rawValue: statusRaw) ?? .failed
    }
}

@Model
final class DeviceRecord {
    var deviceID: UUID
    var primaryMAC: String?
    var ouiVendor: String?
    var displayName: String
    var notes: String
    var tags: [String]
    var firstSeenAt: Date
    var lastSeenAt: Date
    var isIgnored: Bool

    @Relationship(deleteRule: .nullify, inverse: \ScanHostRecord.device)
    var observations: [ScanHostRecord]

    init(
        deviceID: UUID = UUID(),
        primaryMAC: String? = nil,
        displayName: String,
        lastSeenAt: Date = .now
    ) {
        self.deviceID = deviceID
        self.primaryMAC = primaryMAC
        self.displayName = displayName
        self.notes = ""
        self.tags = []
        self.firstSeenAt = lastSeenAt
        self.lastSeenAt = lastSeenAt
        self.isIgnored = false
        self.observations = []
    }

    var snapshot: DeviceSnapshot {
        DeviceSnapshot(
            id: deviceID,
            primaryMAC: primaryMAC,
            ipv4: observations.sorted { $0.observedAt > $1.observedAt }.first?.ipv4,
            vendor: ouiVendor,
            hostname: observations.sorted { $0.observedAt > $1.observedAt }.first?.hostname,
            lastSeenAt: lastSeenAt
        )
    }
}

@Model
final class ScanHostRecord {
    var hostID: UUID
    var observedAt: Date
    var ipv4: String?
    var ipv6: String?
    var mac: String?
    var hostname: String?
    var vendor: String?
    var deviceClassRaw: String
    var osGuess: String?
    var firmwareGuess: String?
    var cpes: [String]
    var discoveryMethods: [String]
    var latencyMS: Double?
    var isGateway: Bool
    var isThisMac: Bool
    var run: ScanRunRecord?
    var device: DeviceRecord?

    @Relationship(deleteRule: .cascade, inverse: \ServiceRecord.host)
    var services: [ServiceRecord]

    @Relationship(deleteRule: .cascade, inverse: \EvidenceRecord.host)
    var evidence: [EvidenceRecord]

    @Relationship(deleteRule: .cascade, inverse: \FindingRecord.host)
    var findings: [FindingRecord]

    init(draft: HostDraft, observedAt: Date = .now) {
        self.hostID = draft.id
        self.observedAt = observedAt
        self.ipv4 = draft.identity.ipv4
        self.ipv6 = draft.identity.ipv6
        self.mac = draft.identity.mac
        self.hostname = draft.identity.hostname
        self.vendor = draft.identity.vendor
        self.deviceClassRaw = draft.deviceClass.rawValue
        self.osGuess = draft.flags.osGuess
        self.firmwareGuess = draft.flags.firmwareGuess
        self.cpes = draft.flags.cpes
        self.discoveryMethods = draft.flags.discoveryMethods
        self.latencyMS = draft.flags.latencyMS
        self.isGateway = draft.flags.isGateway
        self.isThisMac = draft.flags.isThisMac
        self.services = draft.services.map(ServiceRecord.init(draft:))
        self.evidence = draft.evidence.map(EvidenceRecord.init(draft:))
        self.findings = draft.findings.map(FindingRecord.init(draft:))
    }

    var deviceClass: DeviceClass {
        DeviceClass(rawValue: deviceClassRaw) ?? .unknown
    }

    var displayName: String {
        hostname ?? ipv4 ?? mac ?? "Unknown host"
    }

    var driftSnapshot: HostDriftSnapshot {
        HostDriftSnapshot(
            ipv4: ipv4,
            mac: mac,
            hostname: hostname,
            ports: services.map(\.port)
        )
    }
}

@Model
final class ServiceRecord {
    var serviceID: UUID
    var port: Int
    var transportRaw: String
    var stateRaw: String
    var protocolGuess: String?
    var banner: String?
    var product: String?
    var version: String?
    var host: ScanHostRecord?

    init(draft: ServiceDraft) {
        self.serviceID = draft.id
        self.port = draft.port
        self.transportRaw = draft.transport.rawValue
        self.stateRaw = draft.state.rawValue
        self.protocolGuess = draft.protocolGuess
        self.banner = draft.banner
        self.product = draft.product
        self.version = draft.version
    }
}

@Model
final class EvidenceRecord {
    var evidenceID: UUID
    var kindRaw: String
    var summary: String
    var payload: String
    var collectedAt: Date
    var host: ScanHostRecord?

    init(draft: EvidenceDraft) {
        self.evidenceID = draft.id
        self.kindRaw = draft.kind.rawValue
        self.summary = draft.summary
        self.payload = draft.payload
        self.collectedAt = draft.collectedAt
    }
}

@Model
final class FindingRecord {
    var findingID: UUID
    var source: String
    var title: String
    var detail: String
    var severityRaw: String
    var cvss: Double?
    var cveIDs: [String]
    var cpes: [String]
    var confidenceRaw: String
    var categoryRaw: String
    var remediation: String
    var statusRaw: String
    var evidenceIDs: [UUID]
    var host: ScanHostRecord?

    init(draft: FindingDraft) {
        self.findingID = draft.id
        self.source = draft.source
        self.title = draft.title
        self.detail = draft.detail
        self.severityRaw = draft.classification.severity.rawValue
        self.cvss = draft.classification.cvss
        self.cveIDs = draft.classification.cveIDs
        self.cpes = draft.classification.cpes
        self.confidenceRaw = draft.classification.confidence.rawValue
        self.categoryRaw = draft.classification.category.rawValue
        self.remediation = draft.remediation
        self.statusRaw = draft.status.rawValue
        self.evidenceIDs = draft.evidenceIDs
    }

    var severity: Severity {
        Severity(rawValue: severityRaw) ?? .info
    }
}

enum ScannerSchema {
    static let models: [any PersistentModel.Type] = [
        NetworkScopeRecord.self,
        ScanRunRecord.self,
        DeviceRecord.self,
        ScanHostRecord.self,
        ServiceRecord.self,
        EvidenceRecord.self,
        FindingRecord.self,
    ]
}
