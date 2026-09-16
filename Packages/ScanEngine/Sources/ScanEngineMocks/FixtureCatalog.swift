import Foundation
import ScanEngine

public enum FixtureCatalog: Sendable {
    public static func hosts(in cidr: IPv4CIDR) -> [HostDraft] {
        let gatewayIP = cidr.host(at: 1)?.dotted ?? "192.168.1.1"
        let macIP = cidr.host(at: 10)?.dotted ?? "192.168.1.10"
        let nasIP = cidr.host(at: 20)?.dotted ?? "192.168.1.20"
        let printerIP = cidr.host(at: 40)?.dotted ?? "192.168.1.40"
        let cameraIP = cidr.host(at: 77)?.dotted ?? "192.168.1.77"
        return [
            gateway(ip: gatewayIP),
            thisMac(ip: macIP),
            nas(ip: nasIP),
            printer(ip: printerIP),
            camera(ip: cameraIP),
        ]
    }

    private static func gateway(ip: String) -> HostDraft {
        let cert = EvidenceDraft(
            kind: .certificate,
            summary: "TLS certificate expired",
            payload: "notAfter=2024-01-01T00:00:00Z CN=router.local"
        )
        let finding = FindingDraft(
            source: "tls",
            title: "Expired TLS certificate",
            detail: "The device presents a certificate that expired on 2024-01-01.",
            classification: FindingClassification(
                severity: .medium,
                category: .hygiene,
                confidence: .high
            ),
            remediation: "Install a current certificate on the admin HTTPS interface.",
            evidenceIDs: [cert.id]
        )
        return HostDraft(
            identity: HostIdentity(
                ipv4: ip,
                mac: "00:11:22:33:44:55",
                hostname: "gateway.local",
                vendor: "Example Router"
            ),
            deviceClass: .router,
            flags: HostFlags(
                osGuess: "RouterOS",
                firmwareGuess: "6.49.10",
                discoveryMethods: ["arp", "icmp"],
                isGateway: true
            ),
            services: [
                ServiceDraft(port: 80, protocolGuess: "http"),
                ServiceDraft(port: 443, protocolGuess: "https"),
            ],
            evidence: [cert],
            findings: [finding]
        )
    }

    private static func thisMac(ip: String) -> HostDraft {
        HostDraft(
            identity: HostIdentity(
                ipv4: ip,
                mac: "a4:83:e7:00:00:01",
                hostname: "scanner-host.local",
                vendor: "Apple"
            ),
            deviceClass: .computer,
            flags: HostFlags(
                osGuess: "macOS",
                discoveryMethods: ["arp", "mdns"],
                isThisMac: true
            ),
            services: [
                ServiceDraft(port: 22, protocolGuess: "ssh", banner: "SSH-2.0-OpenSSH_9.8"),
            ]
        )
    }

    private static func nas(ip: String) -> HostDraft {
        let banner = EvidenceDraft(
            kind: .banner,
            summary: "HTTP Server header",
            payload: "Server: nginx\r\nX-NAS-Model: DS920+"
        )
        let finding = FindingDraft(
            source: "cve-match",
            title: "CVE-2024-0001 in DSM (fixture)",
            detail: "Fixture CVE match for a dated DSM build. Replace with live NVD data in a later milestone.",
            classification: FindingClassification(
                severity: .high,
                category: .cve,
                confidence: .medium,
                cvss: 7.5,
                cveIDs: ["CVE-2024-0001"],
                cpes: ["cpe:2.3:o:synology:diskstation_manager:7.1:*:*:*:*:*:*:*"]
            ),
            remediation: "Update DSM to the vendor’s current supported release.",
            evidenceIDs: [banner.id]
        )
        return HostDraft(
            identity: HostIdentity(
                ipv4: ip,
                mac: "00:11:32:aa:bb:cc",
                hostname: "lab-nas.local",
                vendor: "Synology"
            ),
            deviceClass: .nas,
            flags: HostFlags(
                osGuess: "DSM",
                firmwareGuess: "7.1-42661",
                cpes: ["cpe:2.3:o:synology:diskstation_manager:7.1:*:*:*:*:*:*:*"],
                discoveryMethods: ["arp", "http"]
            ),
            services: [
                ServiceDraft(port: 5000, protocolGuess: "http", product: "DSM"),
                ServiceDraft(port: 5001, protocolGuess: "https", product: "DSM"),
            ],
            evidence: [banner],
            findings: [finding]
        )
    }

    private static func printer(ip: String) -> HostDraft {
        let banner = EvidenceDraft(
            kind: .banner,
            summary: "Telnet greeting",
            payload: "HP JetDirect telnet ready"
        )
        let finding = FindingDraft(
            source: "hygiene",
            title: "Telnet is open",
            detail: "TCP/23 accepted a connection. Telnet is unencrypted.",
            classification: FindingClassification(
                severity: .high,
                category: .exposure,
                confidence: .high
            ),
            remediation: "Disable Telnet and use TLS or WPA-enterprise admin access instead.",
            evidenceIDs: [banner.id]
        )
        return HostDraft(
            identity: HostIdentity(
                ipv4: ip,
                mac: "3c:d9:2b:10:20:30",
                hostname: "office-printer.local",
                vendor: "HP"
            ),
            deviceClass: .printer,
            flags: HostFlags(discoveryMethods: ["arp", "mdns"]),
            services: [
                ServiceDraft(port: 23, protocolGuess: "telnet", banner: "HP JetDirect telnet ready"),
                ServiceDraft(port: 9100, protocolGuess: "jetdirect"),
            ],
            evidence: [banner],
            findings: [finding]
        )
    }

    private static func camera(ip: String) -> HostDraft {
        HostDraft(
            identity: HostIdentity(
                ipv4: ip,
                mac: "00:12:16:99:88:77",
                hostname: nil,
                vendor: "Generic IoT"
            ),
            deviceClass: .iot,
            flags: HostFlags(
                firmwareGuess: nil,
                discoveryMethods: ["arp"]
            ),
            services: [
                ServiceDraft(port: 80, protocolGuess: "http"),
            ],
            findings: [
                FindingDraft(
                    source: "firmware",
                    title: "Firmware version unknown",
                    detail: "The host responded but no product/version could be fingerprinted.",
                    classification: FindingClassification(
                        severity: .info,
                        category: .unidentified,
                        confidence: .low
                    ),
                    remediation: "Identify the device manually or add credentials for an authenticated check.",
                    evidenceIDs: []
                ),
            ]
        )
    }
}
