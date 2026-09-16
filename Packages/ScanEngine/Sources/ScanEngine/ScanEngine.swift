public protocol ScanEngine: Sendable {
    func availableScopes() async -> [NetworkScopeDraft]
    func events(for configuration: ScanConfiguration) async -> AsyncStream<ScanEvent>
    func cancel() async
}
