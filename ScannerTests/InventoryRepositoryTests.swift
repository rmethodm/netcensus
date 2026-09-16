import Foundation
import SwiftData
import Testing
@testable import Scanner
import ScanEngine

@MainActor
struct InventoryRepositoryTests {
    @Test func mergeKeepsOneDeviceWhenMACMatchesAcrossRuns() throws {
        let container = try Self.container()
        let repository = InventoryRepository(context: container.mainContext)
        let scope = NetworkScopeDraft(
            interfaceName: "en0",
            cidr: "192.168.1.0/24",
            isAssessable: true
        )
        let configuration = ScanConfiguration(scope: scope)
        let first = HostDraft(
            identity: HostIdentity(ipv4: "192.168.1.20", mac: "00:11:32:aa:bb:cc", hostname: "nas")
        )
        _ = try repository.persistCompletedRun(
            configuration: configuration,
            startedAt: .now,
            hosts: [first],
            summary: ScanSummary(hostCount: 1, findingCount: 0, status: .completed)
        )
        let moved = HostDraft(
            identity: HostIdentity(ipv4: "192.168.1.21", mac: "00:11:32:aa:bb:cc", hostname: "nas")
        )
        _ = try repository.persistCompletedRun(
            configuration: configuration,
            startedAt: .now,
            hosts: [moved],
            summary: ScanSummary(hostCount: 1, findingCount: 0, status: .completed)
        )
        let devices = try container.mainContext.fetch(FetchDescriptor<DeviceRecord>())
        #expect(devices.count == 1)
        #expect(devices.first?.primaryMAC == "00:11:32:aa:bb:cc")
        #expect(devices.first?.observations.count == 2)
    }

    @Test func pruneDeletesOldRunsButKeepsNewest() throws {
        let container = try Self.container()
        let repository = InventoryRepository(context: container.mainContext)
        let scope = NetworkScopeDraft(
            interfaceName: "en0",
            cidr: "10.0.0.0/24",
            isAssessable: true
        )
        let configuration = ScanConfiguration(scope: scope)
        let host = HostDraft(identity: HostIdentity(ipv4: "10.0.0.1"))
        _ = try repository.persistCompletedRun(
            configuration: configuration,
            startedAt: Date().addingTimeInterval(-10 * 24 * 60 * 60),
            hosts: [host],
            summary: ScanSummary(hostCount: 1, findingCount: 0, status: .completed)
        )
        _ = try repository.persistCompletedRun(
            configuration: configuration,
            startedAt: .now,
            hosts: [host],
            summary: ScanSummary(hostCount: 1, findingCount: 0, status: .completed)
        )
        try repository.pruneRuns(olderThanDays: 1)
        let runs = try container.mainContext.fetch(FetchDescriptor<ScanRunRecord>())
        #expect(runs.count == 1)
    }

    private static func container() throws -> ModelContainer {
        let schema = Schema(ScannerSchema.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
