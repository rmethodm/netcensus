import Darwin
import Foundation

public enum ICMPPing: Sendable {
    public static func echo(
        _ address: IPv4Address,
        timeout: Duration = .milliseconds(250),
        identifier: UInt16 = UInt16(truncatingIfNeeded: ProcessInfo.processInfo.processIdentifier)
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            PingSocket.send(address: address, timeout: timeout, identifier: identifier) { success in
                continuation.resume(returning: success)
            }
        }
    }
}

private final class PingSocket: @unchecked Sendable {
    static func send(
        address: IPv4Address,
        timeout: Duration,
        identifier: UInt16,
        completion: @escaping @Sendable (Bool) -> Void
    ) {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard fd >= 0 else {
            completion(false)
            return
        }

        let once = OnceFlag()
        let finish: @Sendable (Bool) -> Void = { value in
            if once.take() {
                close(fd)
                completion(value)
            }
        }

        let sequence = UInt16(truncatingIfNeeded: address.rawValue)
        let packet = echoRequest(identifier: identifier, sequence: sequence)
        var dest = sockaddr_in()
        dest.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_addr = in_addr(s_addr: address.rawValue.bigEndian)

        let sent = withUnsafePointer(to: &dest) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                packet.withUnsafeBytes { raw in
                    sendto(fd, raw.baseAddress, packet.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else {
            finish(false)
            return
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global())
        source.setEventHandler {
            if readMatches(fd: fd, address: address, identifier: identifier, sequence: sequence) {
                source.cancel()
                finish(true)
            }
        }
        source.resume()

        DispatchQueue.global().asyncAfter(deadline: .now() + .nanoseconds(timeout.nanosecondCount)) {
            source.cancel()
            finish(false)
        }
    }

    private static func readMatches(
        fd: Int32,
        address: IPv4Address,
        identifier: UInt16,
        sequence: UInt16
    ) -> Bool {
        var buffer = [UInt8](repeating: 0, count: 128)
        var src = sockaddr_in()
        var srcLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let received = withUnsafeMutablePointer(to: &src) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                recvfrom(fd, &buffer, buffer.count, 0, sa, &srcLen)
            }
        }
        let sourceIP = IPv4Address(rawValue: UInt32(bigEndian: src.sin_addr.s_addr))
        return received > 0
            && sourceIP == address
            && ICMPEcho.matchesReply(Array(buffer.prefix(received)), identifier: identifier, sequence: sequence)
    }

    private static func echoRequest(identifier: UInt16, sequence: UInt16) -> [UInt8] {
        var packet: [UInt8] = [
            8, 0, 0, 0,
            UInt8(identifier >> 8), UInt8(identifier & 0xff),
            UInt8(sequence >> 8), UInt8(sequence & 0xff),
            0x53, 0x43, 0x41, 0x4e,
        ]
        let sum = checksum(packet)
        packet[2] = UInt8(sum >> 8)
        packet[3] = UInt8(sum & 0xff)
        return packet
    }

    private static func checksum(_ data: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        var index = 0
        while index + 1 < data.count {
            sum += UInt32(data[index]) << 8 | UInt32(data[index + 1])
            index += 2
        }
        if index < data.count {
            sum += UInt32(data[index]) << 8
        }
        while sum >> 16 != 0 {
            sum = (sum & 0xffff) + (sum >> 16)
        }
        return ~UInt16(truncatingIfNeeded: sum)
    }
}

enum ICMPEcho: Sendable {
    static func matchesReply(_ buffer: [UInt8], identifier: UInt16, sequence: UInt16) -> Bool {
        guard let icmp = icmpHeader(in: buffer) else { return false }
        guard icmp.count >= 8, icmp[0] == 0 else { return false }
        let id = UInt16(icmp[4]) << 8 | UInt16(icmp[5])
        let seq = UInt16(icmp[6]) << 8 | UInt16(icmp[7])
        return id == identifier && seq == sequence
    }

    private static func icmpHeader(in buffer: [UInt8]) -> [UInt8]? {
        if buffer.count >= 8, buffer[0] == 0 { return buffer }
        if buffer.count >= 28, buffer[0] >> 4 == 4, buffer[20] == 0 {
            return Array(buffer.dropFirst(20))
        }
        return nil
    }
}

