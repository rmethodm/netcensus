public struct MACAddress: Sendable, Equatable, Hashable {
    public let octets: [UInt8]

    public init?(_ raw: String) {
        let hex = raw.filter(\.isHexDigit)
        guard hex.count == 12 else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(6)
        var index = hex.startIndex
        for _ in 0..<6 {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        octets = bytes
    }

    public var canonical: String {
        octets.map { String(format: "%02x", $0) }.joined(separator: ":")
    }

    public var ouiPrefix: String {
        octets.prefix(3).map { String(format: "%02x", $0) }.joined(separator: ":")
    }

    public var isBroadcast: Bool {
        octets.allSatisfy { $0 == 0xff }
    }

    public var isMulticast: Bool {
        guard let first = octets.first else { return false }
        return first & 1 == 1
    }
}
