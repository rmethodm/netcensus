import Testing
@testable import ScanEngine

struct ICMPEchoTests {
    @Test func acceptsMatchingEchoReply() {
        let reply: [UInt8] = [0, 0, 0, 0, 0x12, 0x34, 0x00, 0x01, 0x53, 0x43]
        #expect(ICMPEcho.matchesReply(reply, identifier: 0x1234, sequence: 1))
        #expect(!ICMPEcho.matchesReply(reply, identifier: 0x1234, sequence: 2))
        #expect(!ICMPEcho.matchesReply(reply, identifier: 0x0001, sequence: 1))
    }

    @Test func rejectsEchoRequestAndAcceptsIPEncapsulatedReply() {
        let request: [UInt8] = [8, 0, 0, 0, 0x12, 0x34, 0x00, 0x01]
        #expect(!ICMPEcho.matchesReply(request, identifier: 0x1234, sequence: 1))
        var ip = [UInt8](repeating: 0, count: 28)
        ip[0] = 0x45
        ip[20] = 0
        ip[24] = 0x12
        ip[25] = 0x34
        ip[26] = 0
        ip[27] = 1
        #expect(ICMPEcho.matchesReply(ip, identifier: 0x1234, sequence: 1))
    }
}
