import Foundation

final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var taken = false

    func take() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if taken { return false }
        taken = true
        return true
    }
}

extension Duration {
    var millisecondCount: Int {
        let parts = components
        let total = parts.seconds * 1_000 + parts.attoseconds / 1_000_000_000_000_000
        if total > Int.max { return Int.max }
        if total < 0 { return 0 }
        return Int(total)
    }

    var nanosecondCount: Int {
        let parts = components
        let total = parts.seconds * 1_000_000_000 + parts.attoseconds / 1_000_000_000
        if total > Int.max { return Int.max }
        if total < 0 { return 0 }
        return Int(total)
    }
}
