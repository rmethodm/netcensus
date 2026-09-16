public enum HygieneProvider: Sendable {
    public static func assess(_ host: HostDraft) -> HostDraft {
        if host.flags.isThisMac { return host }
        var result = host
        flagTelnet(&result)
        flagFTP(&result)
        flagCleartextHTTP(&result)
        flagExpiredCertificate(&result)
        flagUPnPGateway(&result)
        flagUnidentified(&result)
        return result
    }

    private static func flagTelnet(_ host: inout HostDraft) {
        guard let service = host.openPort(23) else { return }
        FindingBuilder.append(
            to: &host,
            spec: FindingSpec(
                source: "hygiene",
                title: "Telnet is open",
                detail: "TCP/23 accepted a connection. Telnet sends credentials in the clear.",
                classification: FindingClassification(
                    severity: .high,
                    category: .exposure,
                    confidence: .high
                ),
                remediation: "Disable Telnet and use SSH or the vendor’s TLS admin interface.",
                evidence: EvidenceDraft(
                    kind: .banner,
                    summary: "Telnet port open",
                    payload: service.banner ?? "tcp/23 open"
                )
            )
        )
    }

    private static func flagFTP(_ host: inout HostDraft) {
        guard let service = host.openPort(21) else { return }
        FindingBuilder.append(
            to: &host,
            spec: FindingSpec(
                source: "hygiene",
                title: "FTP is open",
                detail: "TCP/21 is open. FTP is unencrypted unless the service is explicitly FTPS.",
                classification: FindingClassification(
                    severity: .medium,
                    category: .exposure,
                    confidence: .medium
                ),
                remediation: "Disable FTP or require FTPS/SFTP.",
                evidence: EvidenceDraft(
                    kind: .banner,
                    summary: "FTP port open",
                    payload: service.banner ?? "tcp/21 open"
                )
            )
        )
    }

    private static func flagCleartextHTTP(_ host: inout HostDraft) {
        guard host.openPort(80) != nil, host.openPort(443) == nil else { return }
        FindingBuilder.append(
            to: &host,
            spec: FindingSpec(
                source: "hygiene",
                title: "HTTP without TLS",
                detail: "The host speaks HTTP on port 80 and did not present HTTPS on 443.",
                classification: FindingClassification(
                    severity: .medium,
                    category: .hygiene,
                    confidence: .medium
                ),
                remediation: "Enable HTTPS and redirect or disable plaintext HTTP.",
                evidence: EvidenceDraft(
                    kind: .note,
                    summary: "HTTP without HTTPS",
                    payload: "tcp/80 open; tcp/443 closed or unseen"
                )
            )
        )
    }

    private static func flagExpiredCertificate(_ host: inout HostDraft) {
        guard let cert = host.evidence.first(where: {
            $0.kind == .certificate && $0.summary.uppercased().contains("EXPIRED")
        }) else { return }
        FindingBuilder.append(
            to: &host,
            spec: FindingSpec(
                source: "tls",
                title: "Expired TLS certificate",
                detail: "The certificate presented during fingerprinting is expired.",
                classification: FindingClassification(
                    severity: .medium,
                    category: .hygiene,
                    confidence: .high
                ),
                remediation: "Install a current certificate on the TLS service.",
                evidence: EvidenceDraft(
                    kind: .certificate,
                    summary: cert.summary,
                    payload: cert.payload
                )
            )
        )
    }

    private static func flagUPnPGateway(_ host: inout HostDraft) {
        let blob = host.haystack
        guard blob.contains("internetgatewaydevice") || blob.contains("wanipconnection") else { return }
        FindingBuilder.append(
            to: &host,
            spec: FindingSpec(
                source: "hygiene",
                title: "UPnP IGD is advertised",
                detail: "This host advertises an Internet Gateway Device. UPnP on a router can expose port mappings.",
                classification: FindingClassification(
                    severity: .medium,
                    category: .exposure,
                    confidence: .medium
                ),
                remediation: "Disable UPnP on the WAN-facing router unless you require it.",
                evidence: EvidenceDraft(
                    kind: .upnpXml,
                    summary: "UPnP IGD",
                    payload: String(blob.prefix(500))
                )
            )
        )
    }

    private static func flagUnidentified(_ host: inout HostDraft) {
        if host.flags.isThisMac { return }
        if host.flags.firmwareGuess != nil { return }
        if SoftwareVersion.extract(from: host.haystack) != nil { return }
        let looksManaged = host.openPort(80) != nil
            || host.openPort(443) != nil
            || host.haystack.contains("upnp")
        guard looksManaged else { return }
        FindingBuilder.append(
            to: &host,
            spec: FindingSpec(
                source: "firmware",
                title: "Firmware version unknown",
                detail: "The host responded but no product/version could be fingerprinted, so missing updates cannot be assessed.",
                classification: FindingClassification(
                    severity: .info,
                    category: .unidentified,
                    confidence: .low
                ),
                remediation: "Identify the device manually or add credentials for an authenticated check.",
                evidence: EvidenceDraft(
                    kind: .note,
                    summary: "No version",
                    payload: host.identity.ipv4 ?? host.id.uuidString
                )
            )
        )
    }
}
