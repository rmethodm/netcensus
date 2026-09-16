public enum ScanProfile: String, Sendable, Codable, CaseIterable, Identifiable {
    case quick
    case standard
    case full

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .quick: "Quick"
        case .standard: "Standard"
        case .full: "Full"
        }
    }

    public var discoveryTCPPorts: [UInt16] {
        switch self {
        case .quick: []
        case .standard: [80, 443, 22]
        case .full: [80, 443, 22, 445, 8080, 8443]
        }
    }

    public var fingerprintTCPPorts: [UInt16] {
        switch self {
        case .quick:
            [80, 443]
        case .standard:
            [22, 23, 80, 139, 443, 445, 548, 631, 3389, 5000, 5001, 5900, 8000, 8080, 8443, 9100]
        case .full:
            [21, 22, 23, 25, 80, 110, 139, 143, 443, 445, 515, 548, 631, 993, 995, 1883, 3306, 3389, 5000, 5001, 5432, 5900, 8000, 8080, 8443, 9100, 9200]
        }
    }
}

public enum ScanPhase: String, Sendable, Codable, CaseIterable {
    case discovering
    case fingerprinting
    case assessing
    case completed
}

public enum ScanStatus: String, Sendable, Codable {
    case queued
    case running
    case paused
    case cancelled
    case failed
    case completed
}

public enum DeviceClass: String, Sendable, Codable, CaseIterable {
    case computer
    case phone
    case accessPoint
    case iot
    case printer
    case nas
    case router
    case virtualMachine
    case unknown

    public var title: String {
        switch self {
        case .computer: "Computer"
        case .phone: "Phone"
        case .accessPoint: "Access point"
        case .iot: "IoT"
        case .printer: "Printer"
        case .nas: "NAS"
        case .router: "Router"
        case .virtualMachine: "Virtual machine"
        case .unknown: "Unknown"
        }
    }
}

public enum Transport: String, Sendable, Codable {
    case tcp
    case udp
}

public enum ServiceState: String, Sendable, Codable {
    case open
    case closed
    case filtered
    case unknown
}

public enum EvidenceKind: String, Sendable, Codable {
    case banner
    case httpHeader
    case httpBodyExcerpt
    case upnpXml
    case certificate
    case snmp
    case mdns
    case tls
    case note
}

public enum Severity: String, Sendable, Codable, Comparable, CaseIterable {
    case info
    case low
    case medium
    case high
    case critical

    public static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.rank < rhs.rank
    }

    var rank: Int {
        switch self {
        case .info: 0
        case .low: 1
        case .medium: 2
        case .high: 3
        case .critical: 4
        }
    }
}

public enum Confidence: String, Sendable, Codable, CaseIterable {
    case low
    case medium
    case high
}

public enum FindingCategory: String, Sendable, Codable, CaseIterable {
    case cve
    case firmware
    case missingUpdate
    case exposure
    case hygiene
    case unidentified
}

public enum FindingStatus: String, Sendable, Codable {
    case open
    case acknowledged
    case ignored
    case resolved
}
