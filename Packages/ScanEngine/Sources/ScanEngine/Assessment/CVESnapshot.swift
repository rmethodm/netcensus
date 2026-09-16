import Foundation

public struct CVEEntry: Sendable, Equatable, Codable {
    public var id: String
    public var cvss: Double
    public var title: String
    public var products: [String]
    public var cpe: String?
    public var minVersion: String?
    public var maxVersionExclusive: String?
    public var remediation: String

    public init(
        id: String,
        cvss: Double,
        title: String,
        products: [String],
        cpe: String? = nil,
        minVersion: String? = nil,
        maxVersionExclusive: String? = nil,
        remediation: String
    ) {
        self.id = id
        self.cvss = cvss
        self.title = title
        self.products = products
        self.cpe = cpe
        self.minVersion = minVersion
        self.maxVersionExclusive = maxVersionExclusive
        self.remediation = remediation
    }
}

public struct CVESnapshot: Sendable, Equatable, Codable {
    public var version: String
    public var entries: [CVEEntry]

    public init(version: String, entries: [CVEEntry]) {
        self.version = version
        self.entries = entries
    }

    public static func bundled() -> CVESnapshot {
        if let url = Bundle.module.url(forResource: "cve-subset", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let snapshot = try? JSONDecoder().decode(CVESnapshot.self, from: data) {
            return snapshot
        }
        return CVESnapshot(version: "empty", entries: [])
    }
}

public enum CVEMatcher: Sendable {
    public static func matches(_ entry: CVEEntry, haystack: String, version: SoftwareVersion?) -> Confidence? {
        let tokens = entry.products.map { $0.lowercased() }
        guard !tokens.isEmpty, tokens.allSatisfy({ haystack.contains($0) }) else { return nil }
        guard let minRaw = entry.minVersion, let maxRaw = entry.maxVersionExclusive else {
            return version == nil ? .low : .medium
        }
        guard let version else { return .low }
        if let min = SoftwareVersion(minRaw), version < min { return nil }
        if let max = SoftwareVersion(maxRaw), !(version < max) { return nil }
        return .high
    }
}

public enum CVEMatchProvider: Sendable {
    public static func assess(_ host: HostDraft, snapshot: CVESnapshot) -> HostDraft {
        var result = host
        let haystack = host.haystack
        let version = SoftwareVersion.extract(from: haystack)
        for entry in snapshot.entries {
            guard let confidence = CVEMatcher.matches(entry, haystack: haystack, version: version) else {
                continue
            }
            let severity = severity(for: entry.cvss)
            FindingBuilder.append(
                to: &result,
                spec: FindingSpec(
                    source: "cve-match",
                    title: "\(entry.id): \(entry.title)",
                    detail: "Matched product tokens \(entry.products.joined(separator: ", "))"
                        + (version.map { " at version \($0.parts.map(String.init).joined(separator: "."))" } ?? " (version not confirmed)."),
                    classification: FindingClassification(
                        severity: severity,
                        category: .cve,
                        confidence: confidence,
                        cvss: entry.cvss,
                        cveIDs: [entry.id],
                        cpes: entry.cpe.map { [$0] } ?? []
                    ),
                    remediation: entry.remediation,
                    evidence: EvidenceDraft(
                        kind: .note,
                        summary: entry.id,
                        payload: String(haystack.prefix(500))
                    )
                )
            )
        }
        return result
    }

    private static func severity(for cvss: Double) -> Severity {
        if cvss >= 9 { return .critical }
        if cvss >= 7 { return .high }
        if cvss >= 4 { return .medium }
        return .low
    }
}
