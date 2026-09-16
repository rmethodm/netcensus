# Scanner

Native macOS app that inventories devices on a network you are authorized to assess, fingerprints them, and records vulnerabilities and missing updates — without exploits or brute-force.

See `docs/planning/` for the product plan.

## Current (pre-v1.0)

MVP scan/assess loop is in place. A Developer ID Release is notarized. Remaining for v1.0: dogfood on a real LAN, then a download page.

- Live discovery, fingerprinting, and assessment
- Export JSON/CSV/Markdown; inventory new/gone/changed
- Acknowledge / ignore findings; hide ignored in the inbox
- Scheduled scans while the app is open; optional Open at login
- Keychain-backed SNMPv2c, SSH keys, and HTTP basic (one stored login, no spraying)
- Optional scan when the app opens (pairs with Open at login)
- Retention prune; quieter unidentified findings

## Build

```bash
cd /Users/rmethodm/Macdev-local/Macosapps/Scanner
xcodegen generate
swift test --package-path Packages/ScanEngine
xcodebuild -scheme Scanner -destination 'platform=macOS' test
```

Requires Xcode 27, macOS 15+, SwiftLint (`brew install swiftlint`).

## Notarize (Developer ID)

```bash
chmod +x scripts/notarize.sh
./scripts/notarize.sh
```

Uses the Apple ID signed into Xcode (team `MNC9M36A88`). Optional for later runs:

```bash
xcrun notarytool store-credentials notarytool --team-id MNC9M36A88
```
