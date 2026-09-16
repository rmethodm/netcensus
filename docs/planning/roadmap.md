# Scanner — Roadmap

**Last Updated**: 2026-09-16

## Timeline Overview

```
Planning   Engine spike   MVP UI    Assess/CVE   Polish     v1.0
|====1w====|=====3w======|===2w====|====2w=====|===2w====|====>
```

Solo or small team. Calendar time ~10 weeks to a notarized MVP if engine work is full-time.

## Milestones

### Milestone 1: Project + engine contracts (Week 1)

- [x] Xcode project (macOS, SwiftUI, Swift 6)
- [x] Local SPM `ScanEngine` with DTOs and `ScanSession` protocol
- [x] Fake engine that emits fixture hosts (UI can proceed in parallel)
- [x] Authorization screen + scope model
- [x] SwiftData schema v1
- [x] SwiftLint
- [x] Git + first commit

### Milestone 2: Discovery (Weeks 2–3)

- [x] Interface + CIDR
- [x] ARP table read + sweep
- [x] ICMP / TCP ping
- [x] mDNS browse
- [x] SSDP M-SEARCH
- [x] Live table of hosts
- [x] Rate limit + cancel
- [x] Tests with fixtures; loopback integration test

### Milestone 3: Fingerprint + ports (Weeks 4–5)

- [x] TCP connect profiles
- [x] Banner grab (truncated)
- [x] HTTP(S) title/headers
- [x] TLS cert summary
- [x] UPnP device XML
- [x] MAC OUI vendor table
- [x] Device detail evidence UI

### Milestone 4: Assessment (Weeks 6–7)

- [x] Hygiene provider
- [x] CVE snapshot format + matcher
- [x] Ship first snapshot (even if subset)
- [x] Firmware provider protocol + 1–2 vendors
- [x] SNMP GET if public / stored community
- [x] Optional SSH read-only profile (slip-able)
- [x] Findings inbox

### Milestone 5: Inventory, export, notarization (Weeks 8–9)

- [x] Device merge + first/last seen
- [x] Diff new/gone/changed
- [x] Markdown/JSON/CSV export
- [x] Hardened Runtime + notarize
- [x] Privacy policy (local data, no telemetry)
- [x] In-app policy page

### Milestone 6: v1.0

- [ ] Two-week dogfood on a real lab + a “boring” home LAN
- [ ] Fix false-positive top offenders
- [ ] Direct download page or GitHub Releases
- [x] Notarize a Release build (`notarytool`, Developer ID)

## Version Planning

### v1.0 — MVP

Discover, fingerprint, assess (hygiene + CVE + limited firmware), history, export, optional SNMP/HTTP creds. SSH if time.

### v1.1

Sparkle updates, richer firmware providers, IPv6 neighbor discovery. Scheduled scans (while the app is open) and retention prune shipped early.

### v1.2

nmap XML import, custom port lists, better reports (PDF later if needed).

### v2.0 / iOS

iOS viewer, optional iCloud or file sync, policy baselines.

## Feature Release Schedule

| Version | Features | Target |
|---------|----------|--------|
| v1.0 | Discovery, fingerprint, CVE/hygiene, inventory, export | ~10 weeks |
| v1.1 | Schedule, Sparkle, more firmware, IPv6 | +1–2 months |
| v1.2 | nmap import, custom ports | +3 months |
| v2.0 | iOS companion | After Mac is trusted |

## Dependencies & Blockers

- **Local Network TCC** on recent macOS — must be designed and tested on a clean Mac user.
- **CVE snapshot pipeline** — needs a build script; blocker for assessment milestone.
- **OUI database** — IEEE OUI list bundling/licensing (public, but keep updated).
- **Notarization** of an unsandboxed network scanner — expect questions; keep probes documented.

## Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| ARP/ICMP blocked | High | Medium | Layered discovery; label methods |
| CVE false positives | High | High | Confidence + evidence; conservative version match |
| Scope creep into “mini Nessus” | High | High | Out-of-scope list is binding |
| Legal misuse | High | Low | Auth gate, local CIDR default, no WAN |
| iOS promised too early | Medium | Medium | Explicitly after Mac v1.0 |

## Resource Allocation (solo)

- **Development**: majority
- **Design**: system HIG, no custom illustration sprint
- **Testing**: fixture tests + personal LAN dogfood
- **Legal copy**: privacy policy + authorization strings (short, precise)

## Success Metrics

See [overview.md](./overview.md). Ship bar: a /24 Standard scan completes, findings are evidence-backed, export is usable in a client note.

## Notes

- Do not start iOS until Mac inventory export is stable — that file **is** the iOS v1 data API.
- If Week 7 slips, drop credentialed SSH, keep unauthenticated assessment.

## Related Documents

- [features.md](./features.md)
- [overview.md](./overview.md)
