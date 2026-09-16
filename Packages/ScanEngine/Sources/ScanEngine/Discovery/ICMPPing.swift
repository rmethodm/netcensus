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

        let packet = echoRequest(identifier: identifier, sequence: 1)
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
            var buffer = [UInt8](repeating: 0, count: 128)
            let received = recv(fd, &buffer, buffer.count, 0)
            if received > 0, isEchoReply(buffer, identifier: identifier) {
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

    private static func isEchoReply(_ buffer: [UInt8], identifier: UInt16) -> Bool {
        guard buffer.count >= 8 else { return false }
        if buffer[0] == 0 {
            let id = UInt16(buffer[4]) << 8 | UInt16(buffer[5])
            return id == identifier
        }
        if buffer.count >= 28, buffer[20] == 0 {
            let id = UInt16(buffer[24]) << 8 | UInt16(buffer[25])
            return id == identifier
        }
        return false
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

