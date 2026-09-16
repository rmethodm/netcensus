import Foundation

public struct ScanReport: Sendable, Codable, Equatable {
    public var generatedAt: Date
    public var interfaceName: String
    public var cidr: String
    public var profile: String
    public var summary: ScanSummary?
    public var hosts: [HostDraft]

    public init(
        generatedAt: Date = .now,
        interfaceName: String,
        cidr: String,
        profile: String,
        summary: ScanSummary? = nil,
        hosts: [HostDraft]
    ) {
        self.generatedAt = generatedAt
        self.interfaceName = interfaceName
        self.cidr = cidr
        self.profile = profile
        self.summary = summary
        self.hosts = hosts
    }

    public var findingCount: Int {
        hosts.reduce(0) { $0 + $1.findings.count }
    }
}

public enum ScanReportFormat: String, Sendable, CaseIterable {
    case json
    case csv
    case markdown

    public var fileExtension: String {
        switch self {
        case .json: "json"
        case .csv: "csv"
        case .markdown: "md"
        }
    }

    public var contentTypeDescription: String {
        switch self {
        case .json: "JSON"
        case .csv: "CSV"
        case .markdown: "Markdown"
        }
    }
}

public enum ScanReportFormatter: Sendable {
    public static func render(_ report: ScanReport, as format: ScanReportFormat) throws -> Data {
        switch format {
        case .json: try json(report)
        case .csv: Data(csv(report).utf8)
        case .markdown: Data(markdown(report).utf8)
        }
    }

    public static func json(_ report: ScanReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(report)
    }

    public static func csv(_ report: ScanReport) -> String {
        var rows = [
            ["ipv4", "hostname", "mac", "vendor", "class", "ports", "findings", "severity"].joined(separator: ","),
        ]
        for host in report.hosts {
            let ports = host.services.map { String($0.port) }.sorted().joined(separator: " ")
            let titles = host.findings.map(\.title).joined(separator: "; ")
            let severity = host.highestSeverity?.rawValue ?? ""
            rows.append(
                [
                    csvField(host.identity.ipv4 ?? ""),
                    csvField(host.identity.hostname ?? ""),
                    csvField(host.identity.mac ?? ""),
                    csvField(host.identity.vendor ?? ""),
                    csvField(host.deviceClass.rawValue),
                    csvField(ports),
                    csvField(titles),
                    csvField(severity),
                ].joined(separator: ",")
            )
        }
        return rows.joined(separator: "\n") + "\n"
    }

    public static func markdown(_ report: ScanReport) -> String {
        var lines: [String] = [
            "# Scanner report",
            "",
            "- Generated: \(report.generatedAt.formatted(date: .abbreviated, time: .shortened))",
            "- Scope: `\(report.interfaceName)` \(report.cidr)",
            "- Profile: \(report.profile)",
            "- Hosts: \(report.hosts.count)",
            "- Findings: \(report.findingCount)",
            "",
        ]
        for host in report.hosts {
            lines.append(contentsOf: hostMarkdownLines(host))
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    public static func hostMarkdown(_ host: HostDraft) -> String {
        hostMarkdownLines(host).joined(separator: "\n") + "\n"
    }

    private static func hostMarkdownLines(_ host: HostDraft) -> [String] {
        var lines = [
            "## \(host.identity.displayName)",
            "",
            "- Class: \(host.deviceClass.title)",
            "- IPv4: \(host.identity.ipv4 ?? "—")",
            "- MAC: \(host.identity.mac ?? "—")",
            "- Vendor: \(host.identity.vendor ?? "—")",
        ]
        if !host.services.isEmpty {
            let ports = host.services.map { "\($0.port)/\($0.transport.rawValue)" }.joined(separator: ", ")
            lines.append("- Ports: \(ports)")
        }
        if host.findings.isEmpty {
            lines.append("- Findings: none")
        } else {
            lines.append("- Findings:")
            for finding in host.findings {
                lines.append(
                    "  - **\(finding.classification.severity.rawValue)** \(finding.title) — \(finding.remediation)"
                )
            }
        }
        return lines
    }

    static func csvField(_ value: String) -> String {
        if value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
