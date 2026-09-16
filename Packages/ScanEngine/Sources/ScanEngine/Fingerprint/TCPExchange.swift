import Foundation
import Network
import Security

struct TCPExchangeResult: Sendable {
    var body: String
    var certificate: TLSCertSummary?
}

enum TCPExchange: Sendable {
    static func transact(
        host: String,
        port: UInt16,
        useTLS: Bool,
        payload: Data?,
        timeout: Duration = .milliseconds(700)
    ) async -> TCPExchangeResult {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            return TCPExchangeResult(body: "", certificate: nil)
        }
        let box = CertificateBox()
        let parameters = parameters(useTLS: useTLS, box: box)
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: nwPort,
            using: parameters
        )
        return await run(connection: connection, payload: payload, timeout: timeout, box: box)
    }

    private static func parameters(useTLS: Bool, box: CertificateBox) -> NWParameters {
        guard useTLS else { return .tcp }
        let tlsOptions = NWProtocolTLS.Options()
        capture(on: tlsOptions, box: box)
        return NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
    }

    private static func capture(on options: NWProtocolTLS.Options, box: CertificateBox) {
        sec_protocol_options_set_verify_block(
            options.securityProtocolOptions,
            { _, trust, complete in
                let secTrust = sec_trust_copy_ref(trust).takeRetainedValue()
                if let chain = SecTrustCopyCertificateChain(secTrust) as? [SecCertificate],
                   let first = chain.first {
                    box.value = TLSCertSummary.from(certificate: first)
                }
                complete(true)
            },
            DispatchQueue.global()
        )
    }

    private static func run(
        connection: NWConnection,
        payload: Data?,
        timeout: Duration,
        box: CertificateBox
    ) async -> TCPExchangeResult {
        await withCheckedContinuation { continuation in
            let once = OnceFlag()
            let finish: @Sendable (String) -> Void = { body in
                if once.take() {
                    connection.cancel()
                    continuation.resume(returning: TCPExchangeResult(body: body, certificate: box.value))
                }
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let payload {
                        connection.send(content: payload, completion: .contentProcessed { _ in
                            receive(connection, finish: finish)
                        })
                    } else {
                        receive(connection, finish: finish)
                    }
                case .failed, .cancelled:
                    finish("")
                default:
                    break
                }
            }
            connection.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + .nanoseconds(timeout.nanosecondCount)) {
                finish("")
            }
        }
    }

    private static func receive(_ connection: NWConnection, finish: @escaping @Sendable (String) -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4_096) { data, _, _, error in
            if let data, !data.isEmpty {
                finish(String(decoding: data.prefix(4_096), as: UTF8.self))
            } else {
                finish(error == nil ? "" : "")
            }
        }
    }
}

private final class CertificateBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: TLSCertSummary?

    var value: TLSCertSummary? {
        get {
            lock.lock(); defer { lock.unlock() }
            return stored
        }
        set {
            lock.lock(); stored = newValue; lock.unlock()
        }
    }
}
