import Darwin
import Foundation

public struct SNMPSysDescr: Sendable, Equatable {
    public var community: String
    public var sysDescr: String
}

public enum SNMPClient: Sendable {
    /// SNMPv2c GET sysDescr.0. Read-only. No writes.
    public static func sysDescr(
        host: IPv4Address,
        community: String = "public",
        timeout: Duration = .milliseconds(400)
    ) async -> SNMPSysDescr? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(
                    returning: getBlocking(host: host, community: community, timeout: timeout)
                )
            }
        }
    }

    private static func getBlocking(
        host: IPv4Address,
        community: String,
        timeout: Duration
    ) -> SNMPSysDescr? {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var timeoutVal = timeval(
            tv_sec: Int(timeout.millisecondCount / 1000),
            tv_usec: Int32((timeout.millisecondCount % 1000) * 1000)
        )
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeoutVal, socklen_t(MemoryLayout<timeval>.size))

        var dest = sockaddr_in()
        dest.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port = in_port_t(161).bigEndian
        dest.sin_addr = in_addr(s_addr: host.rawValue.bigEndian)

        let packet = getRequest(community: community, oid: [1, 3, 6, 1, 2, 1, 1, 1, 0])
        let sent = withUnsafePointer(to: &dest) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                packet.withUnsafeBytes { raw in
                    sendto(fd, raw.baseAddress, packet.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: 1500)
        let received = recv(fd, &buffer, buffer.count, 0)
        guard received > 0 else { return nil }
        guard let descr = parseOctetString(Data(buffer.prefix(received))) else { return nil }
        return SNMPSysDescr(community: community, sysDescr: descr)
    }

    static func getRequest(community: String, oid: [UInt]) -> Data {
        let communityBytes = Array(community.utf8)
        let oidBytes = encodeOID(oid)
        let binding = ber(0x30, encodeOIDValue(oidBytes) + [0x05, 0x00])
        let pdu = ber(0xA0, ber(0x02, [0x01]) + ber(0x02, [0x00]) + ber(0x02, [0x00]) + ber(0x30, binding))
        let body = ber(0x02, [0x01]) + ber(0x04, communityBytes) + pdu
        return Data(ber(0x30, body))
    }

    static func parseOctetString(_ data: Data) -> String? {
        let bytes = [UInt8](data)
        var index = 0
        var candidates: [String] = []
        while index + 1 < bytes.count {
            if bytes[index] == 0x04 {
                let length = Int(bytes[index + 1])
                let start = index + 2
                if length > 0, start + length <= bytes.count {
                    let text = String(decoding: bytes[start..<(start + length)], as: UTF8.self)
                    if text != "public", !text.isEmpty {
                        candidates.append(text)
                    }
                    index = start + length
                    continue
                }
            }
            index += 1
        }
        return candidates.max(by: { $0.count < $1.count })
    }

    private static func ber(_ tag: UInt8, _ content: [UInt8]) -> [UInt8] {
        [tag, UInt8(content.count)] + content
    }

    private static func encodeOIDValue(_ oidBytes: [UInt8]) -> [UInt8] {
        ber(0x06, oidBytes)
    }

    private static func encodeOID(_ oid: [UInt]) -> [UInt8] {
        guard oid.count >= 2 else { return [] }
        var bytes = [UInt8(oid[0] * 40 + oid[1])]
        for component in oid.dropFirst(2) {
            bytes.append(contentsOf: encodeBase128(component))
        }
        return bytes
    }

    private static func encodeBase128(_ value: UInt) -> [UInt8] {
        if value < 128 { return [UInt8(value)] }
        var chunks: [UInt8] = []
        var remaining = value
        chunks.append(UInt8(remaining & 0x7F))
        remaining >>= 7
        while remaining > 0 {
            chunks.append(UInt8((remaining & 0x7F) | 0x80))
            remaining >>= 7
        }
        return chunks.reversed()
    }
}

public enum SNMPProvider: Sendable {
    public static func assess(_ host: HostDraft, credentials: [ScanCredential] = []) async -> HostDraft {
        guard let ip = host.identity.ipv4, let address = IPv4Address(ip) else { return host }
        var updated = host
        let communities = credentials.filter { $0.kind == .snmpv2c && $0.matches(hostIP: ip) }.map(\.secret)
            + ["public"]
        var seen: Set<String> = []
        for community in communities where seen.insert(community).inserted {
            guard let result = await SNMPClient.sysDescr(host: address, community: community) else {
                continue
            }
            updated.flags.osGuess = updated.flags.osGuess ?? result.sysDescr
            if community == "public" {
                FindingBuilder.append(
                    to: &updated,
                    spec: FindingSpec(
                        source: "snmp",
                        title: "SNMP community “public” is readable",
                        detail: "A GetRequest with community public returned sysDescr.",
                        classification: FindingClassification(
                            severity: .medium,
                            category: .exposure,
                            confidence: .high
                        ),
                        remediation: "Disable SNMPv1/v2c, or set a private community and restrict source addresses.",
                        evidence: EvidenceDraft(
                            kind: .snmp,
                            summary: "sysDescr.0",
                            payload: result.sysDescr
                        )
                    )
                )
            } else {
                updated.evidence.append(
                    EvidenceDraft(kind: .snmp, summary: "sysDescr (stored community)", payload: result.sysDescr)
                )
            }
            break
        }
        return updated
    }
}
