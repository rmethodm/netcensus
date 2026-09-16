import Testing
@testable import ScanEngine

struct HostAccumulatorTests {
    @Test func mergesIdentityByIPv4AndKeepsStableID() {
        var accumulator = HostAccumulator()
        let first = accumulator.upsert(
            HostDraft(
                identity: HostIdentity(ipv4: "192.168.1.20", hostname: "nas.local"),
                flags: HostFlags(discoveryMethods: ["mdns"])
            )
        )
        let second = accumulator.upsert(
            HostDraft(
                identity: HostIdentity(ipv4: "192.168.1.20", mac: "00:11:32:aa:bb:cc"),
                flags: HostFlags(discoveryMethods: ["arp"])
            )
        )
        #expect(second.id == first.id)
        #expect(second.identity.hostname == "nas.local")
        #expect(second.identity.mac == "00:11:32:aa:bb:cc")
        #expect(second.flags.discoveryMethods == ["mdns", "arp"])
        #expect(accumulator.allHosts().count == 1)
    }

    @Test func unionsOpenPorts() {
        var accumulator = HostAccumulator()
        _ = accumulator.upsert(
            HostDraft(
                identity: HostIdentity(ipv4: "10.0.0.5"),
                services: [ServiceDraft(port: 80, protocolGuess: "http")]
            )
        )
        let merged = accumulator.upsert(
            HostDraft(
                identity: HostIdentity(ipv4: "10.0.0.5"),
                services: [ServiceDraft(port: 22, protocolGuess: "ssh")]
            )
        )
        #expect(Set(merged.services.map(\.port)) == [22, 80])
    }
}
