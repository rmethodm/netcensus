# Scanner — User Personas

**Last Updated**: 2026-09-15

## Persona 1: Maya — Independent security consultant

### Demographics

- **Age**: 30–45
- **Occupation**: Independent security consultant / part-time vCISO
- **Location**: Works from a home office; clients are small businesses
- **Tech Savviness**: High

### Background

Maya is hired to tell a dentist’s office or a 20-person shop what is on their LAN and what will get them popped. She currently uses Fing for a first pass, then nmap, then a spreadsheet. Clients hate the Nessus quote for a one-day LAN review.

### Goals

- Walk in, scan the authorized VLAN, leave with a dated inventory and a finding list she can put in a PDF.
- Show evidence when a client says “that printer isn’t a risk.”
- Notice new hosts on a return visit.

### Pain Points

- Consumer scanners hide method and evidence.
- nmap XML → spreadsheet is unpaid time.
- She will not run exploit packs on a client LAN.

### How Scanner Helps

Native Mac app, authorization recorded, evidence-backed findings, export to Markdown/JSON.

### Quote

> “I need the list, the versions, and the CVEs — not a cartoon house with gadgets in it.”

## Persona 2: Jonah — Homelab / security engineer

### Demographics

- **Age**: 25–40
- **Occupation**: Detection engineer or homelab hobbyist
- **Location**: Home rack + day-job corporate laptop (this app runs on his personal Mac)
- **Tech Savviness**: High

### Goals

- Know every device on the lab VLAN, including the random ESP32 he forgot.
- Catch a camera that stopped taking updates.
- Diff this week vs last week after a guest joins Wi-Fi.

### Pain Points

- IoT firmware pages are a scavenger hunt.
- He already has nmap; he wants history and CVE context without standing up OpenVAS.

### How Scanner Helps

Persistent inventory, firmware providers, scheduled scans later, local-only data.

### Quote

> “If it has an IP on my network, I want a row, a last-seen, and whether it’s stale.”

## Persona Comparison

| Aspect | Maya | Jonah |
|--------|------|-------|
| Primary Goal | Client-ready LAN assessment | Continuous homelab inventory |
| Key Pain Point | Evidence + export | Firmware lag + drift |
| Usage Frequency | Per engagement | Weekly / daily |
| Key Feature | Report export + evidence | History diffs |
| Credentials | Client-supplied SNMP/SSH | His own lab creds |

## Non-users (do not design for)

- People who want to “hack the neighbor’s Wi-Fi”
- Red-team exploit operators (use a real C2 / framework)
- Non-technical parents who only want “pause the kid’s iPad” (that’s a router product)
