import Foundation

struct FindingSpec {
    var source: String
    var title: String
    var detail: String
    var classification: FindingClassification
    var remediation: String
    var evidence: EvidenceDraft
}

enum FindingBuilder {
    static func append(to host: inout HostDraft, spec: FindingSpec) {
        let finding = FindingDraft(
            source: spec.source,
            title: spec.title,
            detail: spec.detail,
            classification: spec.classification,
            remediation: spec.remediation,
            evidenceIDs: [spec.evidence.id]
        )
        do {
            try finding.validate()
        } catch {
            return
        }
        host.evidence.append(spec.evidence)
        host.findings.append(finding)
    }
}

extension HostDraft {
    var haystack: String {
        let parts = [
            identity.vendor,
            identity.hostname,
            flags.osGuess,
            flags.firmwareGuess,
        ] + services.compactMap(\.banner) + services.compactMap(\.product)
            + evidence.map(\.payload) + evidence.map(\.summary)
        return parts.compactMap { $0 }.joined(separator: " ").lowercased()
    }

    func openPort(_ port: Int) -> ServiceDraft? {
        services.first { $0.port == port && $0.state == .open }
    }
}
