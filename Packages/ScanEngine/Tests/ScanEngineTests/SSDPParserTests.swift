import Testing
@testable import ScanEngine

struct SSDPParserTests {
    @Test func parsesUnicastReply() {
        let message = """
        HTTP/1.1 200 OK\r
        CACHE-CONTROL: max-age=1800\r
        ST: upnp:rootdevice\r
        USN: uuid:abc::upnp:rootdevice\r
        LOCATION: http://192.168.1.1:80/rootDesc.xml\r
        SERVER: Linux/1.0 UPnP/1.1 Dummy/1.0\r
        \r
        """
        let reply = SSDPParser.parse(message)
        #expect(reply?.ipv4 == "192.168.1.1")
        #expect(reply?.location == "http://192.168.1.1:80/rootDesc.xml")
        #expect(reply?.server?.contains("UPnP") == true)
        #expect(reply?.searchTarget == "upnp:rootdevice")
    }

    @Test func rejectsNonHTTP() {
        #expect(SSDPParser.parse("not a packet") == nil)
    }

    @Test func searchPacketIsMSearch() {
        let text = String(decoding: SSDPParser.searchPacket(), as: UTF8.self)
        #expect(text.contains("M-SEARCH"))
        #expect(text.contains("239.255.255.250:1900"))
        #expect(text.contains("ssdp:all"))
    }
}
