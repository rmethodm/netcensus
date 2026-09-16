import Testing
@testable import ScanEngine

struct IPv4CIDRTests {
    @Test func parsesPrivateSlash24() throws {
        let cidr = try IPv4CIDR("192.168.1.10/24")
        #expect(cidr.cidrString == "192.168.1.0/24")
        #expect(cidr.hostCount == 254)
        #expect(cidr.isRFC1918)
        #expect(cidr.isAssessable)
        #expect(cidr.contains(try #require(IPv4Address("192.168.1.50"))))
        #expect(!cidr.contains(try #require(IPv4Address("192.168.2.1"))))
    }

    @Test func rejectsPublicAndTooWideRanges() throws {
        #expect(try IPv4CIDR("8.8.8.0/24").isAssessable == false)
        #expect(try IPv4CIDR("0.0.0.0/0").isAssessable == false)
        #expect(try IPv4CIDR("10.0.0.0/7").isRFC1918 == false)
        #expect(try IPv4CIDR("10.0.0.0/8").isRFC1918)
        #expect(try IPv4CIDR("172.16.0.0/12").isRFC1918)
        #expect(try IPv4CIDR("169.254.1.0/24").isLinkLocal)
    }

    @Test func prefixLengthFromNetmask() {
        #expect(IPv4CIDR.prefixLength(netmask: "255.255.255.0") == 24)
        #expect(IPv4CIDR.prefixLength(netmask: "255.255.0.0") == 16)
        #expect(IPv4CIDR.prefixLength(netmask: "255.255.255.255") == 32)
        #expect(IPv4CIDR.prefixLength(netmask: "255.0.255.0") == nil)
    }

    @Test func hostOffset() throws {
        let cidr = try IPv4CIDR("10.0.0.0/24")
        #expect(cidr.host(at: 1)?.dotted == "10.0.0.1")
        #expect(cidr.host(at: 77)?.dotted == "10.0.0.77")
        #expect(cidr.host(at: 300) == nil)
    }

    @Test func usableHostsSkipNetworkAndBroadcast() throws {
        let cidr = try IPv4CIDR("192.168.1.0/24")
        let hosts = cidr.usableHosts()
        #expect(hosts.first?.dotted == "192.168.1.1")
        #expect(hosts.last?.dotted == "192.168.1.254")
        #expect(hosts.count == 254)
        #expect(cidr.canEnumerateHosts)
        #expect(try IPv4CIDR("10.0.0.0/16").canEnumerateHosts == false)
    }

    @Test func invalidStrings() {
        #expect(throws: IPv4CIDR.ParseError.invalidFormat) {
            try IPv4CIDR("not-a-cidr")
        }
        #expect(throws: IPv4CIDR.ParseError.invalidAddress) {
            try IPv4CIDR("999.0.0.1/24")
        }
        #expect(throws: IPv4CIDR.ParseError.invalidPrefix) {
            try IPv4CIDR("192.168.1.0/99")
        }
    }
}
