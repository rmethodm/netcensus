import Foundation
import Testing
@testable import ScanEngine

struct SoftwareVersionTests {
    @Test func ordersDottedVersions() throws {
        let older = try #require(SoftwareVersion("7.1.4"))
        let newer = try #require(SoftwareVersion("7.2.2"))
        #expect(older < newer)
        #expect(SoftwareVersion.extract(from: "DSM 7.1.4-42661") == older)
    }
}

struct HygieneProviderTests {
    @Test func flagsTelnet() {
        let host = HostDraft(
            identity: HostIdentity(ipv4: "192.168.1.40"),
            services: [ServiceDraft(port: 23, banner: "JetDirect telnet")]
        )
        let assessed = HygieneProvider.assess(host)
        #expect(assessed.findings.contains { $0.title.contains("Telnet") })
        #expect(!assessed.findings.contains { $0.classification.category == .unidentified })
    }

    @Test func doesNotFlagPingOnlyHostsAsUnidentified() {
        let host = HostDraft(identity: HostIdentity(ipv4: "192.168.1.77"))
        let assessed = HygieneProvider.assess(host)
        #expect(assessed.findings.isEmpty)
    }

    @Test func flagsHTTPWithoutVersionAsUnidentified() {
        let host = HostDraft(
            identity: HostIdentity(ipv4: "10.0.0.8"),
            services: [ServiceDraft(port: 80, protocolGuess: "http")]
        )
        let assessed = HygieneProvider.assess(host)
        #expect(assessed.findings.contains { $0.classification.category == .unidentified })
    }

    @Test func flagsCleartextHTTP() {
        let host = HostDraft(
            identity: HostIdentity(ipv4: "10.0.0.5"),
            flags: HostFlags(firmwareGuess: "1.0"),
            services: [ServiceDraft(port: 80, protocolGuess: "http")]
        )
        let assessed = HygieneProvider.assess(host)
        #expect(assessed.findings.contains { $0.title.contains("HTTP") })
        #expect(!assessed.findings.contains { $0.classification.category == .unidentified })
    }

    @Test func flagsExpiredCertificate() {
        let host = HostDraft(
            identity: HostIdentity(ipv4: "192.168.1.1"),
            flags: HostFlags(firmwareGuess: "1.0", isGateway: true),
            evidence: [
                EvidenceDraft(kind: .certificate, summary: "EXPIRED: cn=router", payload: "EXPIRED"),
            ]
        )
        let assessed = HygieneProvider.assess(host)
        #expect(assessed.findings.contains { $0.title.contains("Expired TLS") })
    }
}

struct CVEMatcherTests {
    @Test func apachePathTraversalMatchesVersionRange() throws {
        let snapshot = CVESnapshot.bundled()
        #expect(snapshot.entries.contains { $0.id == "CVE-2021-41773" })
        let host = HostDraft(
            identity: HostIdentity(ipv4: "10.0.0.8", vendor: "Apache"),
            flags: HostFlags(firmwareGuess: "2.4.49"),
            services: [ServiceDraft(port: 80, banner: "Apache/2.4.49")]
        )
        let assessed = CVEMatchProvider.assess(host, snapshot: snapshot)
        #expect(assessed.findings.contains { $0.classification.cveIDs.contains("CVE-2021-41773") })
    }

    @Test func doesNotMatchUnrelatedBanner() {
        let host = HostDraft(
            identity: HostIdentity(ipv4: "10.0.0.9", hostname: "printer")
        )
        let assessed = CVEMatchProvider.assess(host, snapshot: CVESnapshot.bundled())
        #expect(assessed.findings.isEmpty)
    }
}

struct FirmwareProviderTests {
    @Test func flagsOldSynology() {
        let host = HostDraft(
            identity: HostIdentity(ipv4: "192.168.1.20", vendor: "Synology"),
            flags: HostFlags(firmwareGuess: "7.1.0")
        )
        let assessed = FirmwareProvider.assess(host, catalog: .bundled())
        #expect(assessed.findings.contains { $0.classification.category == .missingUpdate })
    }

    @Test func ignoresCurrentFirmware() {
        let host = HostDraft(
            identity: HostIdentity(ipv4: "192.168.1.20", vendor: "Synology"),
            flags: HostFlags(firmwareGuess: "7.2.2")
        )
        let assessed = FirmwareProvider.assess(host, catalog: .bundled())
        #expect(!assessed.findings.contains { $0.classification.category == .missingUpdate })
    }
}

struct SNMPClientTests {
    @Test func parsesSysDescrSkippingCommunity() {
        let packet = Data([
            0x30, 0x0D,
            0x04, 0x06, 0x70, 0x75, 0x62, 0x6C, 0x69, 0x63,
            0x04, 0x03, 0x44, 0x53, 0x4D,
        ])
        #expect(SNMPClient.parseOctetString(packet) == "DSM")
    }
}
