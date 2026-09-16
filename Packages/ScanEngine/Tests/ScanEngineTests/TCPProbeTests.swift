import Foundation
import Network
import Testing
@testable import ScanEngine

struct TCPProbeTests {
    @Test func connectsToLoopbackListener() async throws {
        let listener = try NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { connection in
            connection.start(queue: .global())
        }
        listener.start(queue: .global())
        let port = try await waitForPort(listener)
        let connected = await TCPProbe.canConnect(host: "127.0.0.1", port: port, timeout: .milliseconds(500))
        listener.cancel()
        #expect(connected)
    }

    @Test func closedPortReturnsFalse() async {
        let connected = await TCPProbe.canConnect(host: "127.0.0.1", port: 1, timeout: .milliseconds(200))
        #expect(connected == false)
    }

    private func waitForPort(_ listener: NWListener) async throws -> UInt16 {
        for _ in 0..<50 {
            if let port = listener.port?.rawValue, port > 0 {
                return port
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        throw ProbeTestError.noPort
    }
}

private enum ProbeTestError: Error {
    case noPort
}

struct ARPTableTests {
    @Test func emptyDumpYieldsNoEntries() {
        #expect(ARPTable.parseDump(Data()).isEmpty)
    }

    @Test func liveReadDoesNotThrow() {
        _ = ARPTable.entries()
    }
}

struct ProbeRateLimiterTests {
    @Test func permitsComplete() async {
        let limiter = ProbeRateLimiter(maxInFlight: 4, perSecond: 1_000)
        let total = await withTaskGroup(of: Int.self) { group in
            for index in 0..<12 {
                group.addTask {
                    await limiter.withPermit { index }
                }
            }
            var sum = 0
            for await value in group { sum += value }
            return sum
        }
        #expect(total == (0..<12).reduce(0, +))
    }
}
