import Foundation
import Network

public enum TCPProbe: Sendable {
    public static func canConnect(
        host: String,
        port: UInt16,
        timeout: Duration = .milliseconds(280)
    ) async -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return false }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        return await withCheckedContinuation { continuation in
            let once = OnceFlag()
            let finish: @Sendable (Bool) -> Void = { value in
                if once.take() {
                    connection.cancel()
                    continuation.resume(returning: value)
                }
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(true)
                case .failed, .cancelled:
                    finish(false)
                default:
                    break
                }
            }
            connection.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + .nanoseconds(timeout.nanosecondCount)) {
                finish(false)
            }
        }
    }
}

