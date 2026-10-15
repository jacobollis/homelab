# Roadmap

Open faults, known gaps and next work, as of 15 October 2026. Listed in priority order within each group.

## Done since the last snapshot (12 October)

- UniFi Cloud Gateway in place, LAN renumbered, gateway hardening complete. [Case study 13](case-studies.md#13-renumbering-a-live-estate-behind-a-new-gateway).
- Zone-based firewall with a Lab zone and five policies. [Networking](networking.md#zone-based-firewall-and-the-lab-vlan).
- `Llm01GpuAbsent` alert, built and proved.
- Certificate alerting fixed: NAS probe added, a real certificate on the Proxmox UI, probe-failure alert added. [Case study 10](case-studies.md#10-two-certificate-probes-that-could-not-fail-loudly).
- UPS shutdown with NUT, an exporter and an unplug test. [Case study 15](case-studies.md#15-a-ups-nobody-was-reading).
- Gateway ICMP probe with a `GatewayDown` alert.
- Leftover snapshots, a stale network stanza and dead monitoring rules removed.

## Open faults

- **RTX 5070 Ti link stability.** Slot capped at Gen4. Closes after seven consecutive clean cold boots. The first is logged. If a load fault recurs at Gen4, the riser gets replaced. See [case study 1](case-studies.md#1-a-gpu-that-fell-off-the-bus-gen5-over-a-gen4-cable).
- **Then: move the firmware's primary display to the integrated GPU,** so firmware stops initialising a card that VFIO later takes. Held back until the link test closes.
- **Wake-on-LAN from power-off fails.** The earlier suspect, a forced link speed, turned out not to exist: the NIC autonegotiates. The remaining suspect is the NIC's link on standby power. Diagnosis planned for the next shutdown.
- **Host and llm01 package updates** are held until the GPU test closes, so a kernel change does not muddy the result.

## Gateway roadmap

1. **Lab VLAN, stages B to D.** Make the host bridge VLAN-aware, tag the lab VM, then prove it reaches Intune and stays compliant while the Proxmox UI and the NAS stay unreachable from it. Screenshots of the policies and failed tests go into this repo.
2. Turn off Teleport. Copy the gateway backup to the NAS.
3. Retire the old UniFi controller container after its rollback week: protected final archive, out of the backup pool, destroyed, its commented probe deleted.
4. Untrusted desktops in their own zone, allowed only SMB to the NAS, with one application-aware block.
5. IoT and guest networks, including mDNS for the speakers across VLANs.
6. WPA2-Enterprise with the gateway's RADIUS server and dynamic VLANs, with the WiFi profile delivered to a Mac by Intune.
7. A time-boxed WireGuard and Teleport lab, torn down afterwards.
8. A syslog receiver for firewall and IPS logs.

## Monitoring and power

1. Check the NAS certificate renewal lands around 24 October. The expiry metric should read about 90 days afterwards.
2. Check the BIOS setting that decides whether the host boots itself when the UPS restores power.
3. Optional: test the full UPS shutdown path at a time the host would be off anyway.
4. Build or delete the dead SMART exporter job.
5. A DNS probe on the tenant domain's MX record, so a deleted record alerts.
6. An expected-downtime design for the dead-man's switch.
7. Rebuild the out-of-band kernel log path (netconsole) on the working NIC. It died with the old one.

## Security hardening

- Move tenant administration to a dedicated cloud-only admin account, then remove Global Administrator from my daily account.
- Windows LAPS through Intune for the lab device, which currently has no local admin route by design.
- DMARC from `p=none` to quarantine, after fixing Proxmox's unaligned notification mail.
- A dedicated least-privilege NAS account for the work desktop's file share mount.
- A NAS-only DNS token for its certificate renewals. The Proxmox host already has its own.
- A dedicated Tailscale tag for the subnet router, so route auto-approval applies to it alone.
- Test, then fix or delete, the SSH rule to the exit nodes.
- Review whether the NAS's SFTP service is needed, and disable it if not.

## Lab work

- Finish Remediations: the scheduled run and the portal device status.
- Retention label: apply it once it propagates.
- Sensitivity label: open the protected file in Word desktop as an outside identity to evidence the refusal.
- Research whether a standard user's one-click override of a threat-intelligence block can be prevented. Record nothing until it is verified.
- Lab device teardown in the correct order once all evidence is banked.

## Infrastructure

- A cable run from the ISP router to replace the PowerLine link, if the household agrees. Two weeks of the gateway's outage and latency log is the evidence for asking.

## Repo

- Publish the Terraform files from the retired infrastructure-as-code container, after a gitleaks pass, so that work has inspectable evidence.
- Firewall policy and failed-test screenshots from the lab VLAN, with addresses redacted.
