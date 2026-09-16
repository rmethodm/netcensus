import Foundation

public struct NetworkScopeDraft: Sendable, Equatable, Identifiable, Codable {
    public var id: String { "\(interfaceName)|\(cidr)" }
    public var interfaceName: String
    public var cidr: String
    public var ipv4: String?
    public var estimatedHostCount: Int
    public var isAssessable: Bool
    public var displayName: String

    public init(
        interfaceName: String,
        cidr: String,
        ipv4: String? = nil,
        estimatedHostCount: Int = 0,
        isAssessable: Bool = false,
        displayName: String? = nil
    ) {
        self.interfaceName = interfaceName
        self.cidr = cidr
        self.ipv4 = ipv4
        self.estimatedHostCount = estimatedHostCount
        self.isAssessable = isAssessable
        self.displayName = displayName ?? interfaceName
    }
}

public struct ScanConfiguration: Sendable, Equatable {
    public var scope: NetworkScopeDraft
    public var profile: ScanProfile
    public var rateLimitPerSecond: Int
    public var includeUDP: Bool
    public var credentials: [ScanCredential]

    public init(
        scope: NetworkScopeDraft,
        profile: ScanProfile = .standard,
        rateLimitPerSecond: Int = 200,
        includeUDP: Bool = false,
        credentials: [ScanCredential] = []
    ) {
        self.scope = scope
        self.profile = profile
        self.rateLimitPerSecond = rateLimitPerSecond
        self.includeUDP = includeUDP
        self.credentials = credentials
    }
}

public struct HostIdentity: Sendable, Equatable, Codable {
    public var ipv4: String?
    public var ipv6: String?
    public var mac: String?
    public var hostname: String?
    public var vendor: String?

    public init(
        ipv4: String? = nil,
        ipv6: String? = nil,
        mac: String? = nil,
        hostname: String? = nil,
        vendor: String? = nil
    ) {
        self.ipv4 = ipv4
        self.ipv6 = ipv6
        self.mac = mac
        self.hostname = hostname
        self.vendor = vendor
    }

    public var displayName: String {
        hostname ?? ipv4 ?? ipv6 ?? mac ?? "Unknown host"
    }
}

public struct HostFlags: Sendable, Equatable, Codable {
    public var osGuess: String?
    public var firmwareGuess: String?
    public var cpes: [String]
    public var discoveryMethods: [String]
    public var latencyMS: Double?
    public var isGateway: Bool
    public var isThisMac: Bool

    public init(
        osGuess: String? = nil,
        firmwareGuess: String? = nil,
        cpes: [String] = [],
        discoveryMethods: [String] = [],
        latencyMS: Double? = nil,
        isGateway: Bool = false,
        isThisMac: Bool = false
    ) {
        self.osGuess = osGuess
        self.firmwareGuess = firmwareGuess
        self.cpes = cpes
        self.discoveryMethods = discoveryMethods
        self.latencyMS = latencyMS
        self.isGateway = isGateway
        self.isThisMac = isThisMac
    }
}

public struct ServiceDraft: Sendable, Equatable, Identifiable, Codable {
    public var id: UUID
    public var port: Int
    public var transport: Transport
    public var state: ServiceState
    public var protocolGuess: String?
    public var banner: String?
    public var product: String?
    public var version: String?

    public init(
        id: UUID = UUID(),
        port: Int,
        transport: Transport = .tcp,
        state: ServiceState = .open,
        protocolGuess: String? = nil,
        banner: String? = nil,
        product: String? = nil,
        version: String? = nil
    ) {
        self.id = id
        self.port = port
        self.transport = transport
        self.state = state
        self.protocolGuess = protocolGuess
        self.banner = banner.map { String($0.prefix(512)) }
        self.product = product
        self.version = version
    }
}

public struct EvidenceDraft: Sendable, Equatable, Identifiable, Codable {
    public var id: UUID
    public var kind: EvidenceKind
    public var summary: String
    public var payload: String
    public var collectedAt: Date

    public init(
        id: UUID = UUID(),
        kind: EvidenceKind,
        summary: String,
        payload: String,
        collectedAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.summary = summary
        self.payload = String(payload.prefix(8_192))
        self.collectedAt = collectedAt
    }
}

public struct FindingClassification: Sendable, Equatable, Codable {
    public var severity: Severity
    public var cvss: Double?
    public var cveIDs: [String]
    public var cpes: [String]
    public var confidence: Confidence
    public var category: FindingCategory

    public init(
        severity: Severity,
        category: FindingCategory,
        confidence: Confidence = .medium,
        cvss: Double? = nil,
        cveIDs: [String] = [],
        cpes: [String] = []
    ) {
        self.severity = severity
        self.cvss = cvss
        self.cveIDs = cveIDs
        self.cpes = cpes
        self.confidence = confidence
        self.category = category
    }
}

public struct FindingDraft: Sendable, Equatable, Identifiable, Codable {
    public var id: UUID
    public var source: String
    public var title: String
    public var detail: String
    public var classification: FindingClassification
    public var remediation: String
    public var evidenceIDs: [UUID]
    public var status: FindingStatus

    public init(
        id: UUID = UUID(),
        source: String,
        title: String,
        detail: String,
        classification: FindingClassification,
        remediation: String,
        evidenceIDs: [UUID],
        status: FindingStatus = .open
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.detail = detail
        self.classification = classification
        self.remediation = remediation
        self.evidenceIDs = evidenceIDs
        self.status = status
    }

    public func validate() throws {
        try FindingValidator.validate(self)
    }
}

public enum FindingValidationError: Error, Equatable {
    case cveMissingIdentifier
    case missingEvidence
}

public enum FindingValidator {
    public static func validate(_ finding: FindingDraft) throws {
        if finding.classification.category == .cve, finding.classification.cveIDs.isEmpty {
            throw FindingValidationError.cveMissingIdentifier
        }
        if finding.classification.category != .unidentified, finding.evidenceIDs.isEmpty {
            throw FindingValidationError.missingEvidence
        }
    }
}

public struct HostDraft: Sendable, Equatable, Identifiable, Codable {
    public var id: UUID
    public var identity: HostIdentity
    public var deviceClass: DeviceClass
    public var flags: HostFlags
    public var services: [ServiceDraft]
    public var evidence: [EvidenceDraft]
    public var findings: [FindingDraft]

    public init(
        id: UUID = UUID(),
        identity: HostIdentity,
        deviceClass: DeviceClass = .unknown,
        flags: HostFlags = HostFlags(),
        services: [ServiceDraft] = [],
        evidence: [EvidenceDraft] = [],
        findings: [FindingDraft] = []
    ) {
        self.id = id
        self.identity = identity
        self.deviceClass = deviceClass
        self.flags = flags
        self.services = services
        self.evidence = evidence
        self.findings = findings
    }

    public var openFindingCount: Int { findings.count }

    public var highestSeverity: Severity? {
        findings.map(\.classification.severity).max()
    }
}

public struct ScanSummary: Sendable, Equatable, Codable {
    public var hostCount: Int
    public var findingCount: Int
    public var status: ScanStatus

    public init(hostCount: Int, findingCount: Int, status: ScanStatus) {
        self.hostCount = hostCount
        self.findingCount = findingCount
        self.status = status
    }
}

public enum ScanEvent: Sendable, Equatable {
    case phaseChanged(ScanPhase)
    case hostDiscovered(HostDraft)
    case hostUpdated(HostDraft)
    case progress(completed: Int, total: Int)
    case completed(ScanSummary)
    case failed(String)
    case cancelled
}
