import Foundation
import Testing
@testable import ScanEngine

struct ScanReportFormatterTests {
    let report = ScanReport(
        generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
        interfaceName: "en0",
        cidr: "192.168.1.0/24",
        profile: "standard",
        summary: ScanSummary(hostCount: 1, findingCount: 1, status: .completed),
        hosts: [
            HostDraft(
                identity: HostIdentity(ipv4: "192.168.1.40", hostname: "printer, office"),
                services: [ServiceDraft(port: 23, banner: "telnet")],
                findings: [
                    FindingDraft(
                        source: "hygiene",
                        title: "Telnet is open",
                        detail: "tcp/23",
                        classification: FindingClassification(
                            severity: .high,
                            category: .exposure,
                            confidence: .high
                        ),
                        remediation: "Disable Telnet",
                        evidenceIDs: []
                    ),
                ]
            ),
        ]
    )

    @Test func jsonRoundTrip() throws {
        let data = try ScanReportFormatter.json(report)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ScanReport.self, from: data)
        #expect(decoded.cidr == "192.168.1.0/24")
        #expect(decoded.hosts.count == 1)
        #expect(decoded.findingCount == 1)
    }

    @Test func csvEscapesCommas() {
        let csv = ScanReportFormatter.csv(report)
        #expect(csv.contains("\"printer, office\""))
        #expect(csv.contains("192.168.1.40"))
        #expect(csv.contains("high"))
    }

    @Test func markdownIncludesHostAndFinding() {
        let markdown = ScanReportFormatter.markdown(report)
        #expect(markdown.contains("# Scanner report"))
        #expect(markdown.contains("192.168.1.40"))
        #expect(markdown.contains("Telnet is open"))
        #expect(ScanReportFormatter.hostMarkdown(report.hosts[0]).contains("Disable Telnet"))
    }
}

struct InventoryDifferTests {
    @Test func classifiesNewGoneAndChangedPorts() {
        let previous = [
            HostDriftSnapshot(ipv4: "192.168.1.1", mac: "00:11:22:33:44:55", ports: [80]),
            HostDriftSnapshot(ipv4: "192.168.1.2", mac: "00:11:22:33:44:66", ports: [22]),
        ]
        let current = [
            HostDriftSnapshot(ipv4: "192.168.1.1", mac: "00:11:22:33:44:55", ports: [80, 443]),
            HostDriftSnapshot(ipv4: "192.168.1.3", mac: "00:11:22:33:44:77", ports: [9100]),
        ]
        let rows = InventoryDiffer.diff(previous: previous, current: current)
        let byIP = Dictionary(uniqueKeysWithValues: rows.map { ($0.snapshot.ipv4 ?? "", $0.status) })
        #expect(byIP["192.168.1.1"] == .changed)
        #expect(byIP["192.168.1.2"] == .disappeared)
        #expect(byIP["192.168.1.3"] == .appeared)
    }
}

struct DogfoodArchiveTests {
    @Test func writesLatestAndDetectsNewHost() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dogfood-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = ScanReport(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            interfaceName: "en0",
            cidr: "192.168.1.0/24",
            profile: "standard",
            hosts: [
                HostDraft(identity: HostIdentity(ipv4: "192.168.1.1"), services: [ServiceDraft(port: 80)]),
            ]
        )
        _ = try DogfoodArchive.write(report: first, to: directory)

        let second = ScanReport(
            generatedAt: Date(timeIntervalSince1970: 1_800_086_400),
            interfaceName: "en0",
            cidr: "192.168.1.0/24",
            profile: "standard",
            hosts: [
                HostDraft(identity: HostIdentity(ipv4: "192.168.1.1"), services: [ServiceDraft(port: 80)]),
                HostDraft(identity: HostIdentity(ipv4: "192.168.1.50"), services: [ServiceDraft(port: 22)]),
            ]
        )
        let result = try DogfoodArchive.write(report: second, to: directory)
        #expect(result.drift.contains { $0.status == .appeared && $0.snapshot.ipv4 == "192.168.1.50" })
        #expect(FileManager.default.fileExists(atPath: result.latestURL.path))
        #expect(DogfoodArchive.loadLatest(in: directory)?.hosts.count == 2)
        let summary = try String(contentsOf: result.summaryURL, encoding: .utf8)
        #expect(summary.contains("New: 192.168.1.50"))
    }
}
