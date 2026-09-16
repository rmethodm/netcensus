import Foundation

public struct FirmwareRelease: Sendable, Equatable, Codable {
    public var name: String
    public var match: [String]
    public var latest: String
    public var advisory: String

    public init(name: String, match: [String], latest: String, advisory: String) {
        self.name = name
        self.match = match
        self.latest = latest
        self.advisory = advisory
    }
}

public struct FirmwareCatalog: Sendable, Equatable, Codable {
    public var version: String
    public var releases: [FirmwareRelease]

    public init(version: String, releases: [FirmwareRelease]) {
        self.version = version
        self.releases = releases
    }

    public static func bundled() -> FirmwareCatalog {
        if let url = Bundle.module.url(forResource: "firmware-catalog", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let catalog = try? JSONDecoder().decode(FirmwareCatalog.self, from: data) {
            return catalog
        }
        return FirmwareCatalog(version: "empty", releases: [])
    }
}

public enum FirmwareProvider: Sendable {
    public static func assess(_ host: HostDraft, catalog: FirmwareCatalog) -> HostDraft {
        var result = host
        let haystack = host.haystack
        for release in catalog.releases {
            let tokens = release.match.map { $0.lowercased() }
            guard tokens.allSatisfy({ HaystackMatch.containsToken($0, in: haystack) }) else { continue }
            let current = tokens.compactMap { HaystackMatch.version(in: haystack, near: $0) }.first
                ?? host.flags.firmwareGuess.flatMap(SoftwareVersion.init)
            guard let current else { continue }
            guard let latest = SoftwareVersion(release.latest), current < latest else { continue }
            FindingBuilder.append(
                to: &result,
                spec: FindingSpec(
                    source: "firmware",
                    title: "\(release.name) appears behind \(release.latest)",
                    detail: "Observed version \(current.parts.map(String.init).joined(separator: ".")) is older than the catalog latest \(release.latest).",
                    classification: FindingClassification(
                        severity: .medium,
                        category: .missingUpdate,
                        confidence: .medium
                    ),
                    remediation: release.advisory,
                    evidence: EvidenceDraft(
                        kind: .note,
                        summary: release.name,
                        payload: String(haystack.prefix(400))
                    )
                )
            )
        }
        return result
    }
}
