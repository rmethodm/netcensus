# Download Netcensus

**Latest:** [GitHub Releases](https://github.com/rmethodm/netcensus/releases)

1. Download `Netcensus-notarized.zip` from the newest release.
2. Verify: `shasum -a 256 Netcensus-notarized.zip` should match the SHA-256 on the release notes (1.0.0 build: `5a7332cd71f738d13b0eedcaa39ab8693e95c302b9c346e94e6bf0157bfc1856`).
3. Unzip and move **Netcensus.app** to `/Applications`.
4. Open it. macOS Gatekeeper should accept the stapled notarization; if it does not, the zip may be incomplete — re-download rather than bypassing Gatekeeper.
5. Confirm you are authorized to assess the selected subnet before the first scan.

Requires **macOS 15+**. There is no account and no telemetry. Results stay on this Mac unless you export them.

Questions: [github.com/rmethodm/netcensus/issues](https://github.com/rmethodm/netcensus/issues).
