import Foundation

public enum CredentialKind: String, Sendable, Codable, CaseIterable, Identifiable {
    case snmpv2c
    case sshKey
    case httpBasic

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .snmpv2c: "SNMPv2c community"
        case .sshKey: "SSH key (read-only)"
        case .httpBasic: "HTTP basic"
        }
    }
}

public enum CredentialScopeKind: String, Sendable, Codable, CaseIterable {
    case host
    case subnet

    public var title: String {
        switch self {
        case .host: "Single host"
        case .subnet: "Subnet"
        }
    }
}

public struct ScanCredential: Sendable, Equatable, Identifiable, Codable {
    public var id: UUID
    public var kind: CredentialKind
    public var label: String
    public var username: String?
    public var target: String
    public var scope: CredentialScopeKind
    public var keyPath: String?
    public var secret: String

    public init(kind: CredentialKind, label: String, target: String, scope: CredentialScopeKind) {
        self.id = UUID()
        self.kind = kind
        self.label = label
        self.target = target
        self.scope = scope
        self.username = nil
        self.keyPath = nil
        self.secret = ""
    }

    public func matches(hostIP: String) -> Bool {
        switch scope {
        case .host:
            return target == hostIP
        case .subnet:
            guard let cidr = try? IPv4CIDR(target), let address = IPv4Address(hostIP) else {
                return target == hostIP
            }
            return cidr.contains(address)
        }
    }
}
