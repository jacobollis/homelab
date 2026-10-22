# Roadmap

Open faults, known gaps and next work, as of 22 October 2026. Listed in priority order within each group.

## Done since the last snapshot (12 October)

- UniFi Cloud Gateway in place, LAN renumbered, gateway hardening complete. [Case study 13](case-studies.md#13-renumbering-a-live-estate-behind-a-new-gateway).
- Zone-based firewall with a Lab zone and five policies, and the lab VM moved onto the Lab VLAN with every allow and deny path proved. [Networking](networking.md#zone-based-firewall-and-the-lab-vlan).
- The gateway's mDNS proxy turned off after a capture showed it reflecting the estate into the lab. [Case study 16](case-studies.md#16-the-gateway-announced-the-estate-into-the-lab).
- IoT zone for the speaker pair, with app control on one port and the mDNS proxy scoped to two networks and one service. [Networking](networking.md#iot-zone-for-the-speaker-pair).
- Separate cloud-only admin account in place, admin roles removed from my daily account, break-glass accounts rechecked. [M365 labs](m365-endpoint-labs.md#separate-admin-account).
- RTX 5070 Ti link investigation closed after nine clean cold boots at Gen4, then the firmware's primary display moved to the integrated GPU. [Case study 1](case-studies.md#1-a-gpu-that-fell-off-the-bus-gen5-over-a-gen4-cable).
- edit01's boot fault fixed and its checks on the Untrusted network finished. [Case study 21](case-studies.md#21-a-video-editing-vm-that-booted-to-a-cursor).
- Host and llm01 upgraded, an unrecorded Docker Engine removed from the host first. [Case study 22](case-studies.md#22-a-docker-engine-on-the-hypervisor-that-nobody-recorded).
- Remediations lab complete: scheduled drift correction proved three times, then the licence wound down. [M365 labs](m365-endpoint-labs.md#remediations).
- Guest network on the gateway's built-in guest zone: internet only, client isolation proved against a positive control. [Networking](networking.md#guest-network).
- Open WebUI in its own container in front of llm01, backed up and probed.
- work01's game library moved to a disk with no backup: archive from 447 GiB back to 36.8 GiB. [Case study 19](case-studies.md#19-a-desktop-backup-that-grew-from-24-to-447-gib).
- NAS: SFTP and rsync off, port 22 closed, DDNS entry removed, monthly data scrubbing scheduled, volume encryption recorded.
- Untrusted zone for the desktop VMs, with SMB to the NAS, direct Tailscale paths and a Discord block. [Networking](networking.md#untrusted-zone-for-the-desktop-vms).
- Teleport off, gateway backups copied to the NAS, DHCP reservations for every fixed-MAC client, client names matched to Tailscale names.
- `Llm01GpuAbsent` alert, built and proved.
- Certificate alerting fixed: NAS probe added, a real certificate on the Proxmox UI, probe-failure alert added. [Case study 10](case-studies.md#10-two-certificate-probes-that-could-not-fail-loudly).
- UPS shutdown with NUT, an exporter and an unplug test. [Case study 15](case-studies.md#15-a-ups-nobody-was-reading).
- Gateway ICMP probe with a `GatewayDown` alert.
- Leftover snapshots, a stale network stanza and dead monitoring rules removed.

## Open faults

- **Wake-on-LAN from power-off fails.** The earlier suspect, a forced link speed, turned out not to exist: the NIC autonegotiates. The remaining suspect is the NIC's link on standby power. Diagnosis planned for the next shutdown.

## Gateway roadmap

1. Retire the old UniFi controller container from 13 November, after a 30-day safety net: protected final archive, out of the backup pool, destroyed, its commented probe deleted.
2. **Next:** WPA2-Enterprise with the gateway's RADIUS server and dynamic VLANs, with the WiFi profile delivered to a Mac by Intune.
3. A time-boxed WireGuard and Teleport lab, torn down afterwards.
4. A syslog receiver for firewall and IPS logs.
5. Open question: the block-to-gateway counter on each segmented network rises with no client on the VLAN. Most likely the gateway's own traffic, not proven.
6. Name the two unidentified things the speakers try: a gateway service and a connection toward the main network. Needs the syslog receiver.
7. Guest network loose ends: ping to the guest gateway fails, the guest zone's counters do not match the tests, and the wired guest port is untested.

## Monitoring and power

1. Record the result and duration of the NAS's first data scrub, started by hand on 19 October. Monthly runs start in November.
2. Check the next work01 archive lands near the desktop's used space, not hundreds of GiB.
3. Check the NAS certificate renewal lands around 24 October. The expiry metric should read about 90 days afterwards.
4. Check the BIOS setting that decides whether the host boots itself when the UPS restores power.
5. Optional: test the full UPS shutdown path at a time the host would be off anyway.
6. Build or delete the dead SMART exporter job.
7. A DNS probe on the tenant domain's MX record, so a deleted record alerts.
8. An expected-downtime design for the dead-man's switch.
9. Rebuild the out-of-band kernel log path (netconsole) on the working NIC. It died with the old one.

## Security hardening

- A passkey for the admin account, once the authentication methods policy is checked.
- Windows LAPS through Intune for the lab device, which currently has no local admin route by design.
- DMARC from `p=none` to quarantine, after fixing Proxmox's unaligned notification mail.
- A dedicated least-privilege NAS account for the work desktop's file share mount.
- A NAS-only DNS token for its certificate renewals. The Proxmox host already has its own.
- A dedicated Tailscale tag for the subnet router, so route auto-approval applies to it alone.
- Test, then fix or delete, the SSH rule to the exit nodes.

## Lab work

- Replacement Mac: corporate enrolment through Company Portal, Platform SSO with the Secure Enclave method, FileVault escrow. [Plan](m365-endpoint-labs.md#next-platform-sso-on-a-replacement-mac-planned).
- Restore the Windows Business plan on my account. The admin centre shows it saved, but the user's licence record has not changed since before the save.
- Retention label: apply it once it propagates.
- Sensitivity label: open the protected file in Word desktop as an outside identity to evidence the refusal.
- Research whether a standard user's one-click override of a threat-intelligence block can be prevented. Record nothing until it is verified.
- Lab device teardown in the correct order once all evidence is banked.

## Infrastructure

- A cable run from the ISP router to replace the PowerLine link, if the household agrees. Two weeks of the gateway's outage and latency log is the evidence for asking.

## Repo

- Publish the Terraform files from the retired infrastructure-as-code container, after a gitleaks pass, so that work has inspectable evidence.
- Firewall policy, deny-test and Intune screenshots from the lab VLAN, taken on 15 October, to add with addresses and device names redacted.
