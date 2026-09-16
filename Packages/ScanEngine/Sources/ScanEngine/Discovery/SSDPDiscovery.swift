import Darwin
import Foundation

public enum SSDPDiscovery: Sendable {
    public static func search(timeout: Duration = .seconds(2)) async -> [SSDPReply] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: searchBlocking(timeout: timeout))
            }
        }
    }

    private static func searchBlocking(timeout: Duration) -> [SSDPReply] {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return [] }
        defer { close(fd) }

        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var timeoutVal = timeval(
            tv_sec: Int(timeout.millisecondCount / 1000),
            tv_usec: Int32((timeout.millisecondCount % 1000) * 1000)
        )
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeoutVal, socklen_t(MemoryLayout<timeval>.size))

        var dest = sockaddr_in()
        dest.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port = in_port_t(1900).bigEndian
        dest.sin_addr = in_addr(s_addr: inet_addr("239.255.255.250"))

        let packet = SSDPParser.searchPacket()
        _ = withUnsafePointer(to: &dest) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                packet.withUnsafeBytes { raw in
                    sendto(fd, raw.baseAddress, packet.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        let deadline = Date().addingTimeInterval(Double(timeout.millisecondCount) / 1000)
        var replies: [SSDPReply] = []
        while Date() < deadline {
            var buffer = [UInt8](repeating: 0, count: 2048)
            let received = recv(fd, &buffer, buffer.count, 0)
            guard received > 0 else { break }
            let text = String(decoding: buffer.prefix(received), as: UTF8.self)
            if let reply = SSDPParser.parse(text) {
                replies.append(reply)
            }
        }
        return unique(replies)
    }

    private static func unique(_ replies: [SSDPReply]) -> [SSDPReply] {
        var seen: Set<String> = []
        return replies.filter { reply in
            let key = [reply.ipv4, reply.location, reply.usn].compactMap { $0 }.joined(separator: "|")
            return seen.insert(key).inserted
        }
    }
}
