import Foundation
import Testing
@testable import ScanEngine

struct InventoryMergerTests {
    let merger = InventoryMerger()
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func matchesByMACEvenWhenIPChanges() {
        let existing = DeviceSnapshot(
            id: UUID(),
            primaryMAC: "AA:BB:CC:DD:EE:FF",
            ipv4: "192.168.1.5",
            lastSeenAt: now
        )
        let host = HostDraft(
            identity: HostIdentity(ipv4: "192.168.1.99", mac: "aa-bb-cc-dd-ee-ff")
        )
        #expect(merger.matchingDeviceID(for: host, in: [existing], now: now) == existing.id)
    }

    @Test func matchesByIPVendorHostnameWithinWindow() {
        let existing = DeviceSnapshot(
            id: UUID(),
            ipv4: "192.168.1.20",
            vendor: "Synology",
            hostname: "lab-nas.local",
            lastSeenAt: now.addingTimeInterval(-3600)
        )
        let host = HostDraft(
            identity: HostIdentity(
                ipv4: "192.168.1.20",
                hostname: "lab-nas.local",
                vendor: "Synology"
            )
        )
        #expect(merger.matchingDeviceID(for: host, in: [existing], now: now) == existing.id)
    }

    @Test func doesNotMatchStaleIPIdentity() {
        let existing = DeviceSnapshot(
            id: UUID(),
            ipv4: "192.168.1.20",
            vendor: "Synology",
            hostname: "lab-nas.local",
            lastSeenAt: now.addingTimeInterval(-8 * 24 * 60 * 60)
        )
        let host = HostDraft(
            identity: HostIdentity(
                ipv4: "192.168.1.20",
                hostname: "lab-nas.local",
                vendor: "Synology"
            )
        )
        #expect(merger.matchingDeviceID(for: host, in: [existing], now: now) == nil)
    }

    @Test func newDeviceWhenNothingMatches() {
        let existing = DeviceSnapshot(
            id: UUID(),
            primaryMAC: "00:11:22:33:44:55",
            ipv4: "192.168.1.1",
            lastSeenAt: now
        )
        let host = HostDraft(
            identity: HostIdentity(ipv4: "192.168.1.77", mac: "00:12:16:99:88:77")
        )
        #expect(merger.matchingDeviceID(for: host, in: [existing], now: now) == nil)
    }
}
