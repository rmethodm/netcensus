import Foundation

public actor ProbeRateLimiter {
    private var inFlight = 0
    private var tokens: Double
    private var lastRefill: Date
    private let maxInFlight: Int
    private let refillPerSecond: Double

    public init(maxInFlight: Int = 32, perSecond: Int = 200) {
        self.maxInFlight = max(1, maxInFlight)
        self.refillPerSecond = Double(max(1, perSecond))
        self.tokens = Double(max(1, perSecond))
        self.lastRefill = Date()
    }

    public func withPermit<T: Sendable>(_ work: @Sendable () async -> T) async -> T {
        await acquire()
        defer { release() }
        return await work()
    }

    private func acquire() async {
        while true {
            refill()
            if inFlight < maxInFlight, tokens >= 1 {
                tokens -= 1
                inFlight += 1
                return
            }
            try? await Task.sleep(for: .milliseconds(8))
        }
    }

    private func release() {
        inFlight = max(0, inFlight - 1)
    }

    private func refill() {
        let now = Date()
        let delta = now.timeIntervalSince(lastRefill)
        tokens = min(refillPerSecond, tokens + max(0, delta) * refillPerSecond)
        lastRefill = now
    }
}
