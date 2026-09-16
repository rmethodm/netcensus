import Darwin

public struct IPv4Address: Sendable, Equatable, Hashable {
    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public init?(_ dotted: String) {
        var addr = in_addr()
        guard inet_pton(AF_INET, dotted, &addr) == 1 else { return nil }
        rawValue = UInt32(bigEndian: addr.s_addr)
    }

    public var dotted: String {
        "\(rawValue >> 24).\((rawValue >> 16) & 0xff).\((rawValue >> 8) & 0xff).\(rawValue & 0xff)"
    }
}

public struct IPv4CIDR: Sendable, Equatable, Hashable {
    public var network: IPv4Address
    public var prefixLength: Int

    public enum ParseError: Error, Equatable {
        case invalidFormat
        case invalidAddress
        case invalidPrefix
    }

    public init(network: IPv4Address, prefixLength: Int) throws {
        guard (0...32).contains(prefixLength) else { throw ParseError.invalidPrefix }
        let masked = IPv4Address(rawValue: network.rawValue & Self.mask(prefixLength))
        self.network = masked
        self.prefixLength = prefixLength
    }

    public init(_ cidr: String) throws {
        let parts = cidr.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let prefix = Int(parts[1]) else { throw ParseError.invalidFormat }
        guard let address = IPv4Address(String(parts[0])) else { throw ParseError.invalidAddress }
        try self.init(network: address, prefixLength: prefix)
    }

    public var cidrString: String {
        "\(network.dotted)/\(prefixLength)"
    }

    public var hostCount: Int {
        if prefixLength >= 31 {
            return prefixLength == 32 ? 1 : 2
        }
        return (1 << (32 - prefixLength)) - 2
    }

    public var isRFC1918: Bool {
        isContained(in: IPv4Address(rawValue: 0x0A00_0000), prefix: 8)
            || isContained(in: IPv4Address(rawValue: 0xAC10_0000), prefix: 12)
            || isContained(in: IPv4Address(rawValue: 0xC0A8_0000), prefix: 16)
    }

    public var isLinkLocal: Bool {
        isContained(in: IPv4Address(rawValue: 0xA9FE_0000), prefix: 16)
    }

    /// Addresses this product will scan without extra WAN confirmation.
    public var isAssessable: Bool {
        isRFC1918 || isLinkLocal
    }

    public func contains(_ address: IPv4Address) -> Bool {
        let mask = Self.mask(prefixLength)
        return (address.rawValue & mask) == (network.rawValue & mask)
    }

    public var canEnumerateHosts: Bool {
        hostCount <= 1024
    }

    public func usableHosts() -> [IPv4Address] {
        if prefixLength >= 31 {
            if prefixLength == 32 { return [network] }
            return compactMapHosts(offsets: [0, 1])
        }
        let last = UInt32((1 << (32 - prefixLength)) - 2)
        return compactMapHosts(offsets: Array(1...last))
    }

    public func host(at offset: UInt32) -> IPv4Address? {
        let space: UInt64 = prefixLength >= 31
            ? (prefixLength == 32 ? 1 : 2)
            : (1 << (32 - prefixLength))
        guard UInt64(offset) < space else { return nil }
        return IPv4Address(rawValue: network.rawValue &+ offset)
    }

    public static func mask(_ prefixLength: Int) -> UInt32 {
        if prefixLength <= 0 { return 0 }
        if prefixLength >= 32 { return .max }
        return UInt32.max << (32 - prefixLength)
    }

    public static func prefixLength(netmask dotted: String) -> Int? {
        guard let mask = IPv4Address(dotted) else { return nil }
        let bits = mask.rawValue
        guard bits == 0 || (~bits & (~bits &+ 1)) == 0 else { return nil }
        return bits.nonzeroBitCount
    }

    private func compactMapHosts(offsets: [UInt32]) -> [IPv4Address] {
        offsets.compactMap(host(at:))
    }

    private func isContained(in parent: IPv4Address, prefix: Int) -> Bool {
        guard prefixLength >= prefix else { return false }
        let mask = Self.mask(prefix)
        return (network.rawValue & mask) == (parent.rawValue & mask)
    }
}
