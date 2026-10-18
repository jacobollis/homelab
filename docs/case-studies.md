# Case studies

Each entry gives the symptom, what I checked, what settled it and what changed. Where a conclusion is still a hypothesis, it says so. Intune and Entra findings that are part of a lab are written up in [M365 and Intune labs](m365-endpoint-labs.md) and summarised here.

## 1. A GPU that fell off the bus: Gen5 over a Gen4 cable

**Status: fix under test.**

**Symptom.** The RTX 5070 Ti in llm01 crashed and recovered under bursty load (Xid 13, 31 and 109) and stayed clean under continuous load. One morning it fell off the bus during driver initialisation at boot (Xid 79). The guest then logged `RmInitAdapter failed` every 30 seconds. The host logged `vfio_bar_restore: reset recovery - restoring BARs`, meaning the card had lost its config space.

**What I checked.**

- The riser's part number from the order confirmation. I had recorded it as 400 mm for months. It is a 600 mm cable rated **PCIe 4.0**.
- The link speed under load with `nvidia-smi --query-gpu=pcie.link.gen.current --format=csv -l 1`. With the slot on Auto, the board and card both support Gen5, a passive riser cannot report its rating, so the link trained **Gen5**, twice the cable's rated signalling rate.
- The timing. The host firmware trained the link at Gen4 speed. The move to Gen5 came at guest driver initialisation, which is exactly where the boot failure happened.
- Host AER counters. They read zero, and they prove nothing: these root ports advertise no AER capability, so errors are never collected. `LaneErrStat` at both ends of the link is independent of AER and is what I use instead.
- A scheduled backup that ran near the failure. Task logs showed it started 20 seconds after the fault, against a running VM, so it was not the cause.

**Change.** Slot capped at Gen4 in BIOS. Confirmed at the root port with `lspci -vvv` showing `Target Link Speed: 16GT/s`. A load test of 20 model load and unload cycles across the link showed generation between 1 and 4, never 5, with no Xid and no lane errors.

**Since then.** `Llm01GpuAbsent` now alerts if the card is missing at boot, so a failed morning cannot pass unnoticed again. See [monitoring](monitoring-and-backups.md#gpu-absent-alert). The cold-boot record has started.

**Why it is not closed.** One boot failure is one event. The host powers off nightly, so every morning is a cold boot through the failure point. Seven consecutive clean mornings closes it. A second suspect, the card also being the firmware's boot VGA device, is deliberately left unchanged until then, so the result has one variable.

**Also learned.** A previous incident with the same `RmInitAdapter` lines had been credited to a hypervisor-hiding CPU flag. Those lines are what a card produces after falling off the bus. The full VM stop and start that applied the flag also reset the card, and that most likely fixed it. I kept the flag and corrected the record.

## 2. A GPU VM that did everything right and showed nothing

**Symptom.** A new desktop VM with the RTX 5080 passed through loaded the NVIDIA driver, set a valid mode and trained the HDMI link. The TV showed nothing usable.

**What went wrong in the diagnosis.** I spent two evenings varying the OS on the broken VM: four Linux userlands, all black. I checked cables, modes, refresh rates, DSC and EDID. I compared kernel display state between a working VM and the broken one. It was identical in every field.

**What settled it.** Inverting the experiment. Booting the same live ISO on a VM that already worked rendered immediately. That proved the VM object was the variable and the OS never had been. A diff of `qm showcmd` output between the two VMs showed no relevant difference in PCI topology or firmware. The difference was CPU pinning: the working VM was pinned to one CCD of the 9950X and its SMT siblings with 16 cores.

**Change.** Pinning plus 16 cores on the new VM, which then drove the TV. It is now required configuration for any GPU VM on this host. The mechanism is unknown, and so is which half of the change mattered. Dropping back to 8 cores with the pinning kept would answer that in one reboot.

**Lessons.** When two systems differ and one works, test the working one. Ask first whether the panel reports no signal or signal with black, because those are different faults. And a diagnosis is only as good as the platform it was made on: an earlier conclusion that a RHEL login manager was defective was made on this same broken VM, and may have been the VM's fault all along.

## 3. A Win32 app that reported an install it never did

**Symptom.** A PowerShell 7 Win32 app showed Installed on the lab device, with the right version present. The report had no exit code and no download time.

**What settled it.** The MsiInstaller event log showed SYSTEM installed that version nine days earlier. The MDM diagnostics log showed the installer was a forgotten line-of-business app for the same product, assigned to the same group. The Win32 app's detection rule found the product code and reported success without installing anything.

**Change.** Deleted the LOB app. The supersedence test that followed showed the full sequence: not found, download, install, exit code 0, detected.

**Lesson.** Detection by product code cannot tell who installed a product. Prove the install happened.

## 4. BitLocker: Intune said Succeeded, the drive said otherwise

The policy required XTS-AES 256. Every setting reported Succeeded and the encryption report said Encrypted. `manage-bde -status`, run as SYSTEM through an Intune platform script because the device has only a standard user, showed **XTS-AES 128**. Windows automatic device encryption had encrypted the drive before the policy arrived, and the method setting applies only at encryption time.

Lesson: read the device before claiming a BitLocker posture. Full write-up in [M365 and Intune labs](m365-endpoint-labs.md#bitlocker-the-premise-failed-and-that-became-the-finding).

## 5. A compliant Mac that Entra could not see

The Mac was enrolled and compliant in Intune. Every Entra sign-in from it showed no device ID. Device-based Conditional Access on macOS needs the Enterprise SSO plug-in, delivered by a configuration profile you deploy on purpose. Deploying it was the only change between Failure and Success. Full write-up in [M365 and Intune labs](m365-endpoint-labs.md#the-sso-extension-finding).

## 6. Linux password compliance that ignored the password policy

Three different ways of making RHEL enforce a 14-character minimum all left Intune reporting the old length. The agent measures the user's actual password at authentication through `pam_intune`, not the configured policy. A password change and one sign-in fixed it.

The mistake worth recording: I made three configuration changes before reading the agent's own log, which listed the expected and actual value for every setting. Evidence first, then hypotheses.

## 7. A five-week outage behind an alert I nearly tuned out

**Symptom.** The Khoj probe alert fired at most boots. The timing suggested a slow start after the nightly power-on, so the obvious fix was a longer `for` on the rule.

**What settled it.** Querying `probe_success` across a boot before touching the rule. It read 0 for the full 30 minutes. The service refused connections. All five containers had exited about five weeks earlier and never restarted, because the compose file had no restart policy.

**Change.** Brought the stack up, added `restart: unless-stopped` to every service, bound an exposed VNC port to localhost, and moved secrets out of the compose file into a mode-600 env file. Verified the next morning: the probe read 1 after a cold boot with no manual start.

**Lesson.** Test a false-positive theory against the data before tuning an alert. Lengthening the timer would have hidden a real outage.

## 8. A mail outage found by someone else

**Symptom.** An outside sender reported a bounce: "Host found but no data record of requested type", for type A.

**What settled it.** The domain's DNS had moved to Cloudflare at some point, and the MX, SPF, autodiscover and DKIM records were never recreated there. The sender found no MX, fell back to the apex A record, found none and gave up. Records in the registrar's DNS panel did nothing, because the nameservers pointed elsewhere.

**Change.** Recreated every record in Cloudflare, enabled DKIM, published DMARC at `p=none`, and verified end to end: Microsoft 365's domain health check, then the receiving side's `Authentication-Results` showing SPF, DKIM and DMARC passing. Microsoft's DKIM enable step failed at first while both CNAMEs already resolved publicly. It succeeded later the same evening without any change.

**Lessons.** Recreate every record before switching nameservers, then check each dependent service's own health page. Read the SOA or NS answer to find the authoritative provider before editing anything. And a service with no probe fails silently until someone else notices, so mail-flow monitoring is on the roadmap.

## 9. A drive test voided by its own control

**Symptom.** An NVMe drive had hung twice in one M.2 slot with clean SMART data. To test it in isolation without taking lanes from a GPU, I put it in a USB enclosure and ran a sustained random-I/O workload. It failed reproducibly at the same point, under both UAS and BOT transports.

**What settled it.** A known-good drive in the same enclosure and workload failed the same way at the same point. That voided both runs. The enclosure's USB bridge wedges under sustained 4K random queued load and takes the host USB controller down with it. Sequential load runs clean.

**Outcome.** The drive's fault was never isolated. It left the estate as a retailer return. The enclosure is now used for sequential work only, on a USB controller that carries nothing the host depends on.

**Lesson.** A failing test rig proves nothing until a known-good part passes it.

## 10. Two certificate probes that could not fail loudly

**Symptom.** The NAS certificate expired in September 2026 with no warning, although a certificates rule group existed. The NAS's renewal task had shown Success every day while its deploy step failed for five weeks.

**What settled it.** Three separate faults.

- **The renewal.** A task's status proves only that it exited cleanly. I rebuilt the deploy to create a throwaway local admin for each run and delete it afterwards, so no admin password is stored, and pointed it at the local HTTP port so deployment never depends on the certificate it replaces. Verified by the certificate DSM actually serves.
- **No probe had ever targeted the NAS.** The rule group probed the Proxmox UI and the old UniFi controller only. Found during the renumber's dependency sweep.
- **The Proxmox probe had failed silently since the July rebuild.** `openssl s_client` showed Proxmox's self-signed certificate. The Let's Encrypt setup from before the rebuild had never been restored, while my notes still said Let's Encrypt. The probe failed TLS verification, so it never produced the expiry metric, so the expiry rule had nothing to evaluate. It was blind, not quiet.

**Change.**

- A NAS probe, resolved through a local hosts entry on the monitoring container. The tailnet name points at an address the monitoring container is not allowed to reach, by design.
- A real certificate on the Proxmox UI from Proxmox's built-in ACME client, using a DNS challenge and a new DNS token scoped to one zone. The token went onto the host without appearing on screen or in any transcript.
- A new `CertProbeFailing` rule, so a probe that cannot read its certificate alerts on its own.
- After each change, I queried the expiry metric and checked that every expected instance appeared.

**Lessons.** Pair every expiry alert with a probe-failure alert. After a rebuild, check what each service actually serves, not what the notes say.

## 11. A config edit that did nothing, and a red alert lost in the noise

While rotating dead-man's switch URLs, a `sed` substitution matched nothing because the old value was typed wrong. sed exits silently when nothing matches. A `grep -o` extract of the URL looked valid inside a broken line. Alertmanager's watchdog check went red, the alert arrived among a batch of test alerts, and it went unnoticed for six days.

Changes: match on a fixed prefix rather than the full old value, grep the file after every edit, test the exact value the service will use, and end every monitoring session by checking that Healthchecks and the Alertmanager alerts page are green or explained.

## 12. A stale device object that still claimed to be compliant

After the Mac mini was factory reset and re-enrolled, Entra held two device objects for it. The stale one still read compliant and managed, left over from the earlier enrolment. Intune mapped only to the live one.

An orphaned object that claims compliance is a risk if anything ever authenticates as it. Safe sequence: disable the stale object, sign in from the Mac and confirm the sign-in log shows the live device ID passing CA001, then delete the stale object. Entra deletes by object ID, not device ID, which matters when two objects share a display name.

## 13. Renumbering a live estate behind a new gateway

**Goal.** Put a UniFi Cloud Gateway in front of the estate, to learn gateway and firewall work and to unblock VLANs and DHCP reservations.

**The design changed before any work started.** The first plan put the ISP router in modem mode and kept the existing subnet. The ISP router belongs to the household, and other people's devices use it, so modem mode was off the table. With the ISP router still routing, the gateway's WAN takes an address in the old subnet, so the LAN behind it had to move. The result is double NAT and a new private /24, with every static device keeping its last octet.

**Dependency sweep.** Before writing the runbook, I grepped the old subnet across the host, every container, the VMs and the NAS, with secrets masked in the output. It found three dependencies my notes did not hold:

- The NAS exported the backup share to the host by IP. Moving the host without a new export rule would have broken every backup.
- The NAS exported the AI image share only to llm01's address from August. llm01's mount had been refused for two months, and nothing had noticed.
- The monitoring container's hosts file held hand-added names that the certificate probes resolve through.

grep cannot see everything, so the runbook also listed by name what had to be checked by hand: Khoj's model URL, which lives in its database, the NAS's task scheduler, and the DNS rewrites at NextDNS and Cloudflare.

**Method.**

- Additive pre-staging first: the new subnet route beside the old one in the Tailscale policy, new NFS export rules, new firewall rules on llm01, and a staged copy of the Prometheus config checked with `promtool`.
- The host and llm01 kept their old address as a second address until cleanup. A session over the old address survives the change, so `netplan try` could be confirmed, and a management path stayed open to anything not yet moved.
- One machine at a time, pilot container first, monitoring last.
- Nine verify gates before cleanup, including a manual backup over the new export, a subnet-route test from a phone on mobile data, and a message sent and received through the relay on the work desktop.
- A written rollback for each stage.

**What went off script, recorded rather than hidden.**

- I recabled before pre-staging, so the pre-staging ran over a temporary alias on the Mac. Statics on one switch keep talking through a renumber. Only traffic leaving the subnet stops.
- The runbook restarted the Proxmox cluster service but not `pvestatd`, which left every guest reported as down and raised a false `Llm01Down`.
- After the old host address was removed, the web UI looked dead. A DNS rewrite still pointed at the old address. The host itself was fine.
- llm01's Tailscale client came back logged out after hours without DNS. Restarting `tailscaled` restored it with the same identity.

**Outcome.** Every gate passed. Two monitoring targets turned out to have no exporter behind them at all, which led to [case study 15](#15-a-ups-nobody-was-reading). The llm01 image share works for the first time since August.

## 14. Gateway hardening, proved rather than assumed

Each gateway change was checked by its effect, not by the setting page.

- **Encrypted DNS.** The gateway's custom DNS option wants a DNS stamp, not a DoH URL, and rejected the URL. I built the stamp, decoded it to check it, then proved it by resolving a name only a NextDNS rewrite knows, through the gateway. The NextDNS test endpoint confirmed DoH with the gateway's device name.
- **IPS.** Turned on in Notify and Block. I then checked that Tailscale still made direct connections through double NAT, from an owned device to an exit node and from a phone on mobile data to the Proxmox UI.
- **Reservations.** The access point was first given a static address inside the DHCP pool, where the gateway could lease the same address to another client. Moved to the static band outside the pool.
- **Zone-based firewall.** Before writing the Lab policies, I read the gateway's routing table. The ISP router's subnet is a connected network on the WAN side, so it counts as External. A rule allowing Lab to the internet would also have allowed Lab to the ISP router and the household's devices. The Lab policies block that subnet explicitly. See [networking](networking.md#zone-based-firewall-and-the-lab-vlan).

## 15. A UPS nobody was reading

**Symptom.** After the renumber, the `nut` scrape job stayed down. Nothing listened on its port, and no UPS software was installed on the host at all. The UPS had been plugged into the host by USB the whole time, but a power cut would have run the host until the battery died, with no shutdown and no alert.

**Change.**

- Installed NUT. The driver first failed with "insufficient permissions on everything", because the UPS was plugged in before the package's udev rule existed. Reloading udev rules and replaying USB add events fixed it.
- The UPS firmware reports a different model from the one the USB ID database names. I recorded both and flagged the label check rather than picking one.
- The UPS's own thresholds were 5 minutes and 10 percent, too little to stop two GPU VMs and wait on network storage. The driver now ignores the UPS's low-battery signal and raises its own at 20 minutes or 30 percent.
- The `upsmon` password was generated on the host and written into both config files without ever being displayed.
- Installed a UPS exporter as a hardened systemd service with a dynamic user, after checking its download against the release checksum file.
- Realigned the runtime alert, which used to fire after the shutdown would already have started.

**Test.** Pulled the UPS's mains plug with the loads on it. NUT logged the switch to battery, with about 60 minutes of runtime at 11 percent load. The first pull was 55 seconds and sent nothing, because the alert resolved inside Alertmanager's group wait. A three-minute pull delivered both messages.

**Still open.** The end-to-end shutdown, and whether the BIOS boots the host by itself when power returns.

## 16. The gateway announced the estate into the lab

**Symptom.** The Lab-to-Gateway block policy had counted tens of thousands of hits since the morning. The lab VLAN held only one VM. The gateway's flow view showed nothing for that policy, even with logging on.

**What settled it.** The Proxmox bridge is VLAN-aware, so the host can see every VLAN on its trunk. I ran a 60-second `tcpdump` on the trunk filtered to the Lab VLAN, with MAC addresses shown. Only two senders appeared: the lab VM, making ordinary HTTPS connections, and the gateway itself.

The gateway was sending IGMP reports, UniFi discovery packets, and mDNS records **reflected from the main network**. They included names and addresses for my phone and Mac mini, and a speaker's model, MAC address and serial number. The firewall blocked the lab VM from connecting to any of them, but it could still read their names and addresses.

The cause was the gateway's mDNS proxy, set to Auto. On Auto it reflects every network's service announcements into every other network. Firewall policy controls connections. It does not control what the gateway itself announces.

**Change.** mDNS proxy set to Off. The main network is the only one with my own devices on it, and mDNS works within one subnet without a proxy. A second capture showed no reflected records.

**What did not change.** The counter kept rising, about 60 a minute even with the lab VM shut down. So the reflection was a real finding, but it was not what the counter counted. I tested the explanation one variable at a time, proxy off and then the VM off, and kept only what each step showed. The remaining traffic is most likely the gateway's own IGMP and discovery packets on the Lab interface. That is recorded as unproven.

**Lessons.** Segmenting with firewall rules is not the same as isolating a segment. Check what the gateway puts on the wire, not only what it allows through. When a vendor's flow view is empty, capture on the wire before concluding there is no traffic.

## 17. Segmentation that quietly sent LAN traffic to London

**Context.** Moving the work desktop VM into the Untrusted zone. The plan said Tailscale would be unaffected, because it leaves through the WAN and its own ACL already limits the desktop to two hosts.

**What I measured.** Before the move, I took a baseline with `tailscale ping` from work01. Both of its allowed peers, the NAS and the Mac mini, answered directly over the LAN, in 1 ms and 7 ms. After the move, both answered `via DERP(lhr)` in 25 to 35 ms, with "direct connection not established".

**Why it mattered.** Nothing failed. Syncthing synced and the message relay worked. But traffic between two machines on the same switch was now going out over the 100 Mbps PowerLine link to a relay in London and back. Tailscale hides a broken direct path by relaying, so without the baseline I would not have seen it.

**Cause.** Tailscale's direct path is WireGuard over UDP between the two machines' LAN addresses. The new zone blocked everything to the main network except SMB, so the direct path was blocked too.

**Change.** One more policy: UDP 41641 from Untrusted to the NAS and the Mac mini only, with return traffic allowed. Those are the same two hosts the tailnet ACL lets work01 reach, so the gateway policy mirrors the ACL, and the ACL still decides which services inside those hosts work01 can use. Both paths went back to direct, at 1 ms and 7 ms.

**Lessons.** Take a `tailscale ping` before and after any segmentation change. A plan's assumption that an overlay network "isn't affected" by the underlay is a claim to test, not a fact.

## 18. A speaker pair behind a firewall, designed from a capture

**Goal.** Move a wired stereo speaker pair onto an IoT network, keep control from the phone app on the main network, and leak nothing into the other segments. The vendor documents ports but not which side connects or how discovery crosses networks, and its own staff advise against cross-VLAN setups. I set a fallback first: if it failed, the speakers would go back.

**Baseline before any change.**

- A capture on each segmented VLAN, with the mDNS proxy Off. The gateway sends its own service query once a minute on every network. Without that baseline, the first capture after the change would have looked like a leak.
- A capture on the main network while relaunching the app. The app discovers by mDNS and by SSDP at the same time. Only mDNS can cross this gateway.
- A passive capture could not see the speaker's full service record. The phone's repeat queries listed answers it already had, so the speaker stayed silent, and other replies went unicast to the phone's switch port. So I asked the speaker directly with `dig @<speaker> -p 5353 -t PTR _sonos._tcp.local`. The answer gave the control port, TCP 1443, and the protocol. That one port became the whole allow rule.

**Change, one stage at a time.**

1. The IoT network and zone, with seven policies. A pre-filled factory address in the DHCP guarding field was corrected before any device joined.
2. The mDNS proxy set to Custom: the main and IoT networks only, the speaker service only. The scope was proved both ways while the speakers were still on the main network. A capture on IoT showed the gateway forwarding the app's query (the positive control). Captures on Lab and Untrusted showed only their baseline (the negative).
3. Both switch ports moved together, because the two speakers form a stereo pair, then both unplugged together so they took new leases. Their WiFi was already off, so no wireless mesh could bridge the old and new networks.

**Result.** The app found and controlled the pair, both channels. The control policy counted 160 hits. That counter is the proof, because the gateway cannot generate traffic into IoT on that port itself. Lab and Untrusted still showed only their baseline.

**One wrong reading, caught.** AirPlay was first reported as still working. That test used the phone's Now Playing controls for the speaker app, which run through the app on 1443. Tested properly, from another app with the speaker app closed, AirPlay was gone, as the proxy scope implies. I left it off.

**Lessons.** Find out what a client actually does before writing cross-VLAN rules. Ask an mDNS device directly when a capture comes up empty. Prove a proxy's scope with a positive and a negative capture. Test a feature from a path that cannot borrow another feature's working route.
