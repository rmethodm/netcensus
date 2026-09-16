# Scanner — UI/UX Design

**Last Updated**: 2026-09-15

## Design System

Professional operations tool, not a consumer “smart home” toy. Dense but not crowded. System materials, not a custom dark-only cyber theme.

### Color Palette

**Light / Dark**: System background and labels.

Semantic (use SF Symbols + text, not color alone):

- Critical: system red
- High: system orange
- Medium: system yellow
- Low: system blue
- Info: system gray
- New since last scan: system teal/mint
- This Mac / gateway: secondary label badges

### Typography

**Font**: SF Pro + SF Mono for IPs, MACs, CVE IDs, banners.

**Text styles**: system (Large Title for window, Headline for device name, Body, Caption, Caption2).

**Dynamic Type**: Supported. Tables should wrap or clip with expansion, not become unusable.

### Spacing

8pt grid. Inspector padding 16pt. Compact table row height with option for comfortable density in Settings.

## Navigation

**Primary pattern**: `NavigationSplitView` three columns (macOS HIG for inspector apps).

1. **Sidebar**: Scans / Inventory / Findings / Reports / Settings
2. **List**: Hosts or findings depending on sidebar
3. **Detail**: Device or finding evidence

Toolbar: interface picker, Start/Stop, profile (Quick/Standard/Full), filter field.

No tab bar. This is a Mac utility.

## Screens

### 1. First-run / authorization

- **Purpose**: Explain local-only assessment, no exploits, user must confirm authorization.
- **Key elements**: Scope (interface, CIDR preview, host count estimate), checkbox + Continue.
- **States**: No interface / Wi-Fi off / VPN-only warning.

### 2. Scan session (home)

- **Purpose**: Run and watch a scan.
- **Key elements**: Phase progress (Discover / Fingerprint / Assess), live host table (IP, name, vendor, ports, finding counts), rate, cancel.
- **States**: Idle, running, paused, completed, failed, cancelled.

### 3. Inventory

- **Purpose**: All devices ever seen on this Mac.
- **Key elements**: Last-seen, new/gone filters, tags, search (IP, MAC, name, CVE).
- **Empty**: “No scans yet — start one on the current network.”

### 4. Device detail

- **Purpose**: Identity, services, findings, evidence, notes, optional credentials.
- **Key elements**: Header (name, vendor, MAC, IPs), finding list grouped by severity, Services table, Evidence (disclosure groups), user notes.
- **States**: Partial fingerprint, host down this run, ignored.

### 5. Findings inbox

- **Purpose**: Cross-host queue for a run or “open findings.”
- **Key elements**: Severity filter, CVE vs hygiene vs firmware, acknowledge/ignore.

### 6. Reports

- **Purpose**: Export last completed run.
- **Key elements**: Format picker (Markdown, JSON, CSV), include/exclude ignored, Save panel.

### 7. Settings

- **Purpose**: Rate limit, port profile defaults, UDP opt-in, NetBIOS off-by-default, CVE snapshot version + refresh, retention, credential list.
- **Not in settings**: “Enable exploit modules.”

## User Flows

### Flow 1: First authorized scan

```
Launch
  → Authorization (scope + confirm)
  → Scan session auto-starts Standard profile
  → Hosts populate
  → Assessment fills finding badges
  → Completed → Inventory + Findings
```

### Flow 2: Investigate a finding

```
Findings inbox
  → Select CVE/hygiene row
  → Device detail (evidence visible)
  → User acknowledges or ignores
  → Optional export snippet
```

### Flow 3: Return visit (drift)

```
Launch
  → Start scan (auth remembered for this interface+CIDR)
  → Inventory filter “New” / “Gone” / “Changed ports”
```

## Empty / error / loading

| Situation | UX |
|-----------|-----|
| No local IPv4 | Explain: connect Ethernet/Wi-Fi; VPN-only may hide LAN |
| Permission denied (Local Network) | System Settings deep link + why |
| Host silent | Show IP from ARP with “no services / no banners” |
| CVE DB missing | Banner: assessment limited to hygiene until snapshot loads |
| Scan cancelled | Keep partial run, mark status cancelled |

## Accessibility

- Every severity badge has a text label, not color-only
- Tables are keyboard navigable (up/down, enter for detail)
- VoiceOver: “Critical finding, CVE-2024-…, on printer 192.168.1.40”
- Reduce Motion: progress bars not indeterminate spinners-only
- Mono IPs announced digit-wise if needed via accessibility labels

## Platform Considerations

### macOS

- Standard menu bar: File (export), Scan (start/stop), View, Help
- Window restoration of split positions
- Menu bar extra **not** in MVP ( Jonah’s scheduled scans → v1.1)

### iOS (later)

- List → detail only
- Banner: “This device list may be incomplete compared to the Mac app”
- No full port scan on iOS MVP companion

## Onboarding

Short, one screen. No paged marketing carousel.

Copy outline:

1. Scanner identifies devices on **networks you are allowed to assess**.
2. It records banners, services, and known vulnerabilities. It does **not** attack devices.
3. Results stay on this Mac unless you export them.

## Design Assets

- **App icon**: TBD (network + inventory, not a skull)
- **SF Symbols**: `wifi.router`, `laptopcomputer`, `printer`, `exclamationmark.triangle`, `checkmark.shield`, `doc.text`, `key`

## Related Documents

- [features.md](./features.md)
- [personas.md](./personas.md)
