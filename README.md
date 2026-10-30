# Fulcrum Homelab

A single-node Proxmox homelab and a Microsoft 365 Business Premium tenant that I build, run and break myself. The homelab is working infrastructure first: my daily desktop, local AI, video editing, monitoring and backups all run on it. The tenant is where I practise endpoint management: Intune, Entra ID, Defender and Purview.

This repo documents how it is built, what failed, how I diagnosed it, and what I changed as a result.

Snapshot: 15 October 2026.

## What this demonstrates

| Area | Evidence | Read |
|---|---|---|
| Endpoint management | Windows Autopilot (user-driven, Entra joined), compliance policies on Windows, macOS, Android and RHEL 10, silent BitLocker, Win32 app packaging with supersedence, update rings, Remediations with scheduled drift correction proved, Platform SSO with the Secure Enclave method, FileVault escrow | [M365 and Intune labs](docs/m365-endpoint-labs.md) |
| Identity and access | Conditional Access requiring a compliant device or app protection, break-glass accounts, consent settings hardened after an accidental admin consent | [M365 and Intune labs](docs/m365-endpoint-labs.md) |
| Endpoint security | Defender for Endpoint onboarded on Windows, macOS and Android, network protection in block mode, web content filtering in Edge and Firefox | [M365 and Intune labs](docs/m365-endpoint-labs.md) |
| Data protection | Sensitivity label with encryption, DLP blocking external email, retention, eDiscovery content search | [M365 and Intune labs](docs/m365-endpoint-labs.md) |
| Network edge | UniFi Cloud Gateway behind a shared ISP router, a live renumber of the whole estate, IPS in block mode, encrypted DNS upstream, zone-based firewall with segmented lab, untrusted-desktop, IoT and guest VLANs, a scoped mDNS proxy, every allow and deny proved by test | [Networking](docs/networking.md) |
| Virtualisation | Proxmox VE 9.2, VFIO passthrough of two GPUs and a whole USB4 controller, a hookscript that keeps two VMs off one GPU | [Architecture](docs/architecture.md) |
| Remote access | Tailscale with a four-zone least-privilege ACL, subnet router, self-hosted exit nodes, tailnet-wide DNS filtering | [Networking](docs/networking.md) |
| Monitoring and resilience | Prometheus, Alertmanager and blackbox_exporter on an independent drive, drive-fault and GPU-absent alerts, certificate expiry and probe-failure alerts, UPS shutdown with NUT, dead-man's switch, offsite backup | [Monitoring and backups](docs/monitoring-and-backups.md) |
| Troubleshooting | Twenty-nine written-up faults and changes, each with the evidence that settled it | [Case studies](docs/case-studies.md) |

## Scope, stated plainly

- This is a personal lab. The tenant has one licensed user and a handful of devices. It is not fleet or production experience, and I do not describe it as such.
- Several lab endpoints are virtual machines on Proxmox. Where that affects a result, the write-up says so.
- Work in progress is marked as in progress. Open faults and known gaps are listed in the [roadmap](docs/roadmap.md).
- I worked through much of this with an AI assistant as a pair. I ran every command, made every portal change and own every decision recorded here.

## Estate at a glance

```mermaid
flowchart LR
  isp["Shared ISP router<br/>(not mine)"] --> gw["UniFi Cloud Gateway Ultra<br/>firewall, IPS, DHCP, DNS"]
  gw --> sw["UniFi 2.5G switch"]
  sw --> ap["UniFi U7 Lite AP"]
  subgraph host["fulcrum-pve (Proxmox VE 9.2)"]
    llm01["llm01 VM<br/>Ollama, RTX 5070 Ti"]
    work01["work01 VM<br/>daily desktop, RTX 5080"]
    edit01["edit01 VM<br/>DaVinci Resolve, RTX 5080"]
    ap01["win11-ap01 VM<br/>Autopilot lab device"]
    mon01["mon01 LXC<br/>Prometheus stack"]
    other["tasks01, khoj01, chat01 LXCs"]
  end
  sw --> host
  sw --> nas["Synology NAS<br/>backups, subnet router"]
  ups["UPS with NUT"] -.-> host
  nas -- "Hyper Backup" --> offsite["Offsite storage box"]
  mon01 -- "alerts" --> phone["Telegram"]
  ap01 --> tenant["M365 Business Premium tenant<br/>Intune, Entra, Defender, Purview"]
  devices["Mac mini, Android, iPhone"] --> tenant
```

## Layout

| Path | Contents |
|---|---|
| [docs/architecture.md](docs/architecture.md) | Host, GPU and USB passthrough, storage, power, guests |
| [docs/networking.md](docs/networking.md) | Gateway, firewall zones, LAN design, Tailscale ACL, DNS, mail |
| [docs/monitoring-and-backups.md](docs/monitoring-and-backups.md) | Alerting design, detectors, UPS, backup jobs, retention |
| [docs/m365-endpoint-labs.md](docs/m365-endpoint-labs.md) | Tenant labs and findings |
| [docs/case-studies.md](docs/case-studies.md) | Faults and changes, diagnosis and outcome |
| [docs/decisions.md](docs/decisions.md) | Design decisions and the reasons for them |
| [docs/lessons.md](docs/lessons.md) | Operating principles learned the hard way |
| [docs/roadmap.md](docs/roadmap.md) | Open faults, known gaps, next work |
| [SANITISATION.md](SANITISATION.md) | What is deliberately left out of this repo, and how that is checked |
| [scripts/sanitise-check.sh](scripts/sanitise-check.sh) | Pre-publish sweep for identifiers that should not be public |

## About

Jacob Ollis. 1st Line IT Support Engineer at a Modern Workplace MSP from October 2026, building toward endpoint management and, longer term, cybersecurity. First-Class BSc in IT.

LinkedIn: https://www.linkedin.com/in/jacobollis/

## Commit conventions

Prefixes `docs:`, `scripts:`, `configs:`, `infra:`, `chore:`, `fix:`. Present tense, under 70 characters, one logical change per commit. A gitleaks pre-commit hook blocks commits containing secrets.
