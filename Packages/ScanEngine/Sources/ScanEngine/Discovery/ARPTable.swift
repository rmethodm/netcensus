import Darwin
import Foundation

public struct ARPEntry: Sendable, Equatable {
    public var ipv4: String
    public var mac: String

    public init(ipv4: String, mac: String) {
        self.ipv4 = ipv4
        self.mac = mac
    }
}

public enum ARPTable: Sendable {
    public static func entries() -> [ARPEntry] {
        parseDump(sysctlDump())
    }

    public static func parseDump(_ data: Data) -> [ARPEntry] {
        guard !data.isEmpty else { return [] }
        var entries: [ARPEntry] = []
        var offset = 0
        let headerSize = MemoryLayout<rt_msghdr>.size

        while offset + headerSize <= data.count {
            let length: Int = data.withUnsafeBytes { raw in
                Int(raw.loadUnaligned(fromByteOffset: offset, as: rt_msghdr.self).rtm_msglen)
            }
            guard length > 0, offset + length <= data.count else { break }

            let addrs: Int32 = data.withUnsafeBytes { raw in
                raw.loadUnaligned(fromByteOffset: offset, as: rt_msghdr.self).rtm_addrs
            }

            if let entry = parseRecord(data: data, start: offset + headerSize, end: offset + length, addrs: addrs) {
                entries.append(entry)
            }
            offset += length
        }
        return unique(entries)
    }

    private static func sysctlDump() -> Data {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_LLINFO]
        var needed: Int = 0
        let mibCount = u_int(mib.count)
        guard sysctl(&mib, mibCount, nil, &needed, nil, 0) == 0, needed > 0 else { return Data() }
        var buffer = [UInt8](repeating: 0, count: needed)
        let result = buffer.withUnsafeMutableBytes { raw in
            sysctl(&mib, mibCount, raw.baseAddress, &needed, nil, 0)
        }
        guard result == 0 else { return Data() }
        return Data(buffer.prefix(needed))
    }

    private static func parseRecord(data: Data, start: Int, end: Int, addrs: Int32) -> ARPEntry? {
        var cursor = start
        var ipv4: String?
        var mac: String?
        var bit: Int32 = 1
        for _ in 0..<8 {
            defer { bit <<= 1 }
            guard addrs & bit != 0 else { continue }
            guard cursor + 2 <= end else { return nil }
            let saLen = Int(data[cursor])
            let family = data[cursor + 1]
            let stride = roundup(saLen == 0 ? 4 : saLen)
            if bit == RTA_DST, family == UInt8(AF_INET), cursor + 8 <= end {
                ipv4 = ipv4String(data, at: cursor + 4)
            }
            if bit == RTA_GATEWAY, family == UInt8(AF_LINK) {
                mac = linkMAC(data, at: cursor, end: end)
            }
            cursor += stride
        }
        guard let ipv4, let mac else { return nil }
        return ARPEntry(ipv4: ipv4, mac: mac)
    }

    private static func ipv4String(_ data: Data, at offset: Int) -> String? {
        guard offset + 4 <= data.count else { return nil }
        let b0 = data[offset]
        let b1 = data[offset + 1]
        let b2 = data[offset + 2]
        let b3 = data[offset + 3]
        return "\(b0).\(b1).\(b2).\(b3)"
    }

    private static func linkMAC(_ data: Data, at offset: Int, end: Int) -> String? {
        guard offset + 8 <= end else { return nil }
        let nlen = Int(data[offset + 5])
        let alen = Int(data[offset + 6])
        guard alen == 6 else { return nil }
        let macStart = offset + 8 + nlen
        guard macStart + 6 <= end, macStart + 6 <= data.count else { return nil }
        let bytes = (0..<6).map { String(format: "%02x", data[macStart + $0]) }
        return bytes.joined(separator: ":")
    }

    private static func roundup(_ value: Int) -> Int {
        if value <= 0 { return MemoryLayout<UInt32>.size }
        return (value + MemoryLayout<UInt32>.size - 1) & ~(MemoryLayout<UInt32>.size - 1)
    }

    private static func unique(_ entries: [ARPEntry]) -> [ARPEntry] {
        var seen: Set<String> = []
        return entries.filter { seen.insert($0.ipv4).inserted }
    }
}
