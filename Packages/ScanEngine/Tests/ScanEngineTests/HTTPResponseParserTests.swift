import Foundation
import Testing
@testable import ScanEngine

struct HTTPResponseParserTests {
    @Test func parsesStatusHeadersAndTitle() {
        let raw = """
        HTTP/1.1 200 OK\r
        Server: nginx/1.24\r
        Content-Type: text/html\r
        \r
        <html><head><title>Lab NAS</title></head><body>ok</body></html>
        """
        let response = HTTPResponseParser.parse(raw)
        #expect(response.statusCode == 200)
        #expect(response.server == "nginx/1.24")
        #expect(response.title == "Lab NAS")
    }

    @Test func missingTitleIsNil() {
        let response = HTTPResponseParser.parse("HTTP/1.0 404 Not Found\r\n\r\nnope")
        #expect(response.statusCode == 404)
        #expect(response.title == nil)
    }
}

struct UPnPDeviceParserTests {
    @Test func readsDeviceFields() {
        let xml = """
        <root><device>
        <deviceType>urn:schemas-upnp-org:device:InternetGatewayDevice:1</deviceType>
        <friendlyName>Home Router</friendlyName>
        <manufacturer>ExampleCo</manufacturer>
        <modelName>Edge 5</modelName>
        <modelNumber>1.2.3</modelNumber>
        <serialNumber>ABC123</serialNumber>
        </device></root>
        """
        let info = UPnPDeviceParser.parse(xml)
        #expect(info.friendlyName == "Home Router")
        #expect(info.manufacturer == "ExampleCo")
        #expect(info.modelNumber == "1.2.3")
        #expect(UPnPDeviceParser.locationURL(from: "http://192.168.1.1:80/root.xml")?.host == "192.168.1.1")
        #expect(UPnPDeviceParser.locationURL(from: "not-a-url") == nil)
    }
}

struct OUILookupTests {
    @Test func matchesCanonicalAndBarePrefixes() {
        let lookup = OUILookup(text: """
        # comment
        A4:83:E7	Apple
        001132 Synology
        """)
        #expect(lookup.vendor(forMAC: "a4:83:e7:00:00:01") == "Apple")
        #expect(lookup.vendor(forMAC: "00-11-32-aa-bb-cc") == "Synology")
        #expect(lookup.vendor(forMAC: "ff:ff:ff:ff:ff:ff") == nil)
    }

    @Test func bundledTableContainsAppleAndSynology() {
        let lookup = OUILookup.bundled()
        #expect(lookup.count > 20)
        #expect(lookup.vendor(forMAC: "00:11:32:aa:bb:cc") == "Synology")
        #expect(lookup.vendor(forMAC: "A4:83:E7:00:00:01") == "Apple")
    }
}

struct DeviceClassGuessTests {
    @Test func printerFromJetDirectPort() {
        let host = HostDraft(
            identity: HostIdentity(ipv4: "192.168.1.40"),
            services: [ServiceDraft(port: 9100, protocolGuess: "jetdirect")]
        )
        #expect(DeviceClassGuess.guess(host) == .printer)
    }

    @Test func nasFromSynologyVendor() {
        let host = HostDraft(
            identity: HostIdentity(ipv4: "192.168.1.20", vendor: "Synology")
        )
        #expect(DeviceClassGuess.guess(host) == .nas)
    }

    @Test func keepsExistingClass() {
        let host = HostDraft(
            identity: HostIdentity(ipv4: "192.168.1.10"),
            deviceClass: .computer,
            services: [ServiceDraft(port: 9100)]
        )
        #expect(DeviceClassGuess.guess(host) == .computer)
    }
}

struct TLSCertSummaryTests {
    @Test func expiredWhenNotAfterIsPast() {
        let summary = TLSCertSummary(
            commonName: "router.local",
            issuer: "self-signed",
            notAfter: Date(timeIntervalSince1970: 1)
        )
        #expect(summary.isExpired)
        #expect(summary.summaryLine.contains("router.local"))
    }
}
