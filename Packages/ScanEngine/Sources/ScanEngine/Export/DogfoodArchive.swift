import Foundation

public struct DogfoodWriteResult: Sendable, Equatable {
    public var runURL: URL
    public var latestURL: URL
    public var summaryURL: URL
    public var drift: [DriftRow]

    public init(runURL: URL, latestURL: URL, summaryURL: URL, drift: [DriftRow]) {
        self.runURL = runURL
        self.latestURL = latestURL
        self.summaryURL = summaryURL
        self.drift = drift
    }
}

public enum DogfoodArchive: Sendable {
    public static func write(report: ScanReport, to directory: URL) throws -> DogfoodWriteResult {
        let runs = directory.appendingPathComponent("runs", isDirectory: true)
        try FileManager.default.createDirectory(at: runs, withIntermediateDirectories: true)
        let previous = loadLatest(in: directory)
        let drift = InventoryDiffer.diff(
            previous: previous?.hosts.map(\.driftSnapshot) ?? [],
            current: report.hosts.map(\.driftSnapshot)
        )
        let stamp = isoStamp(report.generatedAt)
        let runURL = runs.appendingPathComponent("\(stamp).json")
        let latestURL = directory.appendingPathComponent("latest.json")
        let summaryURL = directory.appendingPathComponent("summary.md")
        let json = try ScanReportFormatter.json(report)
        try json.write(to: runURL, options: .atomic)
        try json.write(to: latestURL, options: .atomic)
        try summaryMarkdown(report: report, drift: drift, isFirstRun: previous == nil)
            .write(to: summaryURL, atomically: true, encoding: .utf8)
        return DogfoodWriteResult(runURL: runURL, latestURL: latestURL, summaryURL: summaryURL, drift: drift)
    }

    public static func loadLatest(in directory: URL) -> ScanReport? {
        let url = directory.appendingPathComponent("latest.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ScanReport.self, from: data)
    }

    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Scanner/dogfood", isDirectory: true)
    }

    private static func isoStamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date).replacingOccurrences(of: ":", with: "-")
    }

    private static func summaryMarkdown(
        report: ScanReport,
        drift: [DriftRow],
        isFirstRun: Bool
    ) -> String {
        var counts: [String: Int] = [:]
        for finding in report.hosts.flatMap(\.findings) {
            let key = "\(finding.classification.severity.rawValue) \(finding.title)"
            counts[key, default: 0] += 1
        }
        let findingLines = counts.keys.sorted().map { "- \($0): \(counts[$0] ?? 0)" }
        let changed = drift.filter { $0.status != .unchanged }
        let driftSection: String
        if isFirstRun {
            driftSection = "- First run (no previous inventory)."
        } else if changed.isEmpty {
            driftSection = "- none"
        } else {
            driftSection = changed.map {
                "- \($0.status.title): \($0.snapshot.ipv4 ?? $0.snapshot.hostname ?? $0.snapshot.key)"
            }.joined(separator: "\n")
        }
        return """
        # Dogfood summary

        - Generated: \(report.generatedAt.formatted(date: .abbreviated, time: .shortened))
        - Scope: `\(report.interfaceName)` \(report.cidr)
        - Profile: \(report.profile)
        - Hosts: \(report.hosts.count)
        - Findings: \(report.findingCount)

        ## Findings

        \(findingLines.isEmpty ? "- none" : findingLines.joined(separator: "\n"))

        ## Drift vs previous run

        \(driftSection)
        """
    }
}
