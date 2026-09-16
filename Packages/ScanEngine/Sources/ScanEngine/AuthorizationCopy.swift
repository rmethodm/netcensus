public enum AuthorizationCopy: Sendable {
    public static let version = "2026-09-15-v1"

    public static let title = "Authorized network assessment"

    public static let body = """
    Scanner identifies devices on a network you are allowed to assess. It records banners, \
    services, and known vulnerabilities. It does not attack devices, guess passwords, or run exploits.

    Results stay on this Mac unless you export them.

    Only scan networks you own or have explicit permission to assess.
    """

    public static let confirmation = "I am authorized to assess this network."
}
