# Case studies

Each entry gives the symptom, what I checked, what settled it and what changed. Where a conclusion is still a hypothesis, it says so. Intune and Entra findings that are part of a lab are written up in [M365 and Intune labs](m365-endpoint-labs.md) and summarised here.

## 1. A GPU that fell off the bus: Gen5 over a Gen4 cable

**Status: closed, October 2026.**

**Symptom.** The RTX 5070 Ti in llm01 crashed and recovered under bursty load (Xid 13, 31 and 109) and stayed clean under continuous load. One morning it fell off the bus during driver initialisation at boot (Xid 79). The guest then logged `RmInitAdapter failed` every 30 seconds. The host logged `vfio_bar_restore: reset recovery - restoring BARs`, meaning the card had lost its config space.

**What I checked.**

- The riser's part number from the order confirmation. I had recorded it as 400 mm for months. It is a 600 mm cable rated **PCIe 4.0**.
- The link speed under load with `nvidia-smi --query-gpu=pcie.link.gen.current --format=csv -l 1`. With the slot on Auto, the board and card both support Gen5, a passive riser cannot report its rating, so the link trained **Gen5**, twice the cable's rated signalling rate.
- The timing. The host firmware trained the link at Gen4 speed. The move to Gen5 came at guest driver initialisation, which is exactly where the boot failure happened.
- Host AER counters. They read zero, and they prove nothing: these root ports advertise no AER capability, so errors are never collected. `LaneErrStat` at both ends of the link is independent of AER and is what I use instead.
- A scheduled backup that ran near the failure. Task logs showed it started 20 seconds after the fault, against a running VM, so it was not the cause.

**Change.** Slot capped at Gen4 in BIOS. Confirmed at the root port with `lspci -vvv` showing `Target Link Speed: 16GT/s`. A load test of 20 model load and unload cycles across the link showed generation between 1 and 4, never 5, with no Xid and no lane errors.

**Since then.** `Llm01GpuAbsent` now alerts if the card is missing at boot, so a failed morning cannot pass unnoticed again. See [monitoring](monitoring-and-backups.md#gpu-absent-alert).

**How it closed.** One boot failure is one event, so I set a bar before calling it: seven consecutive clean cold boots at Gen4, each through the driver initialisation where the card had failed. The host powers off most nights, so most mornings are a test. Nine clean cold boots came in over eight days, with `nvidia-smi` listing the card, no Xid lines and `LaneErrStat` at zero. Two of them were logged in a separate chat and nearly missed from the count. The boots ran on two guest kernels, because a kernel update had landed earlier than my notes said, which points the result further at the link speed and away from the kernel. Running the link beyond the cable's rating was the cause. I did not rerun Gen5 as a positive control once the cap was in.

**The second suspect, changed after.** The card was also the firmware's primary display, so the firmware initialised it at every boot before VFIO took it. I left that alone until the record closed, so the result had one variable, then moved the primary display to the integrated GPU. The verify gate I had written for it was wrong: the kernel's `vgaarb` line still named the 5070 Ti as boot VGA afterwards. This host boots with `initcall_blacklist=sysfb_init`, and without sysfb the kernel picks the lowest-addressed VGA device whatever the firmware setting. The evidence for the change is where the firmware screen now appears.

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

## 19. A desktop backup that grew from 24 to 447 GiB

**Symptom.** The work desktop's nightly archive was 24 GiB on 11 October. A week later one run wrote 195 GiB, the next 375 GiB, and a manual run 447 GiB. The backup share's usage climbed with each one.

**Diagnosis.**

- `df` inside the VM showed 456 GB used on the root filesystem, and `du` put 416 GB of it in one directory: a game library I had installed on 14 October. The snapshot list confirmed the install date.
- The VM's filesystem is Btrfs with zstd compression. vzdump compresses with zstd too, so it had almost nothing left to save. The archive tracks used space, not the disk size.
- The offsite job carried the 195 GiB archive over the 100 Mbps PowerLine link at under 3 MB/s, for about half a day.

**A wrong reading, caught.** Proxmox showed the backup share with a 1 TiB total, and I read that as the volume's free space and predicted a Sunday shortfall. The total is the shared folder's quota in DSM, and two days later it read 2 TiB. The prediction was wrong. The quota is the real ceiling, and the volume's free space had never been recorded, so I read it in Storage Manager.

**Decision.** Removing the library would have kept an earlier decision that gaming stays off the host. I chose to keep it, on a disk that backups skip, because the games can be downloaded again from the store and are not worth backing up.

**Change.**

1. Added a 600 GB second virtual disk with `backup=0`, hot-plugged.
2. Formatted it Btrfs, mounted by UUID with `nofail`, so a missing disk cannot stop the desktop booting.
3. Moved the library with the store client's own move tool, then ran `fstrim` on the root filesystem so the thin pool got the freed space back.
4. Freed the three large archives by hand.

**Result.** The next manual archive was 36.8 GiB. An archive that size cannot hold a 340 GB library, so the exclusion works as configured. The share dropped to 24% used.

**Lessons.** Read the guest's own used space before blaming the backup tool. On a compressed filesystem, plan backup space from `df`, not from the compression ratio vzdump shows. Before predicting a shortfall from a storage total, find out which limit that total is.

## 20. A guest network that needed no custom rules

**Goal.** A guest WiFi network that reaches the internet and nothing else, with no guest able to reach another, on the gateway's own guest zone.

**The plan was nearly wrong twice.**

- I planned a custom rule to block the ISP router's LAN. After the network existed, the zone held a built-in rule blocking every private range. Before it existed, the zone showed only a default block, so reading it first would have led to a duplicate rule. I dropped the custom rule.
- The plan named a switch port to set to the guest network. Before changing it, the live port list showed my notes had two ports swapped. The named port carried the Mac mini. Changing it would have moved a managed Mac onto the guest network.

**The form changed a setting behind my back.** The new SSID defaulted to a captive portal. Switching to a standard SSID reset WPA2/WPA3 to WPA2 only. A full reread of the form caught it.

**Test design.** One laptop on the guest SSID with Tailscale quit, so the subnet route could not reach what the guest network should not. Its own DNS profile resolves over DoH, so I tested the gateway's resolver with `dig` against the guest gateway. Every private target timed out: the NAS, the gateway's admin on two networks, the ISP router, a speaker on the IoT network. A public site loaded. For isolation, ping between two guest clients failed, and the same pair answered on the main network. Without that positive control, the failed ping proved nothing.

**What I could not explain.** The hit counters. The rules that should have blocked the private ranges stayed at zero, a different built-in rule counted thousands, and the captive portal rules counted with no portal enabled. A counter shows where the gateway logged a packet, not which rule decided its fate. The deny is proven from the client. The attribution waits for a syslog receiver.

**Lessons.** Read a zone's built-in rules after the network joins it. Read the live port list before changing a port. Reread a whole form after it changes mode. Strip the test client of overlays first. Pair every isolation test with a positive control. Treat hit counters as supporting evidence only.

## 21. A video-editing VM that booted to a cursor

**Symptom.** edit01 showed the firmware splash and the boot menu, then a black screen with a white cursor. The TV had signal. It had gone unnoticed for weeks.

**Leads, before looking.** It was the VM's first boot on a new firewall zone and on a newly upgraded host kernel, so both were suspects. So was missing CPU pinning.

**What settled it, in order.**

1. `qm agent 104 ping` and `network-get-interfaces` from the host. The guest agent answered, with an address on the new network. The OS and the network were up under the black screen. That ruled out the network lead in a minute.
2. A text console. `nvidia-smi` could not reach the driver. The display manager had failed three times to start the display server.
3. `rpm -q kernel --last` and the module tree. The NVIDIA module existed only for the previous kernel. A routine `dnf upgrade` six weeks earlier had installed a newer kernel and made it the default.
4. The VM config. CPU pinning was already set, so my notes were wrong on that point too.

**Cause.** The NVIDIA driver had been installed with NVIDIA's `.run` installer without DKMS, so it was built for one kernel only. With nouveau blacklisted, the first boot on the new kernel had no display driver. The fault predated both the firewall move and the host upgrade.

**Change.** Snapshot first. Installed the same driver version again with `--dkms` on the running kernel. `dkms status` then listed it for that kernel, and future kernel updates rebuild it. After a reboot the login screen came up, `nvidia-smi` showed the card, and DaVinci Resolve opened. I then finished the VM's checks on its firewall zone: lease, internet, and Tailscale showing internet-only peers.

**Also corrected.** My notes had the OS as Rocky Linux 8.6; it had been 8.10 since its build. An attempt to check `dkms` on a system without it triggered PackageKit's prompt, and answering yes installed a package: a change I made without meaning to.

**Lessons.** Ask the guest agent before debugging a black screen. Install out-of-tree drivers with DKMS, and check `dkms status` after a guest kernel update, before the reboot. Read the release file before recording a guest's OS.

## 22. A Docker engine on the hypervisor that nobody recorded

**Context.** A planned upgrade of the Proxmox host, held for a week until the GPU test closed: 191 packages and a new kernel.

**Found first.** `apt update` listed a Docker package source. `dpkg -l` showed Docker Engine and containerd installed two months earlier, with no containers and no images, and nothing in my notes. The install date matched the day I hand-built a container that runs Docker Compose. The likeliest explanation is that container's install command run in the host shell. I cannot prove it.

**Why it mattered.** Docker sets the iptables FORWARD policy to DROP. Guest traffic on the Proxmox bridge was unaffected only because `net.bridge.bridge-nf-call-iptables` was 0. Turning on the Proxmox firewall for any guest NIC can set it to 1, and then every bridged guest packet would meet Docker's DROP. A latent outage, waiting for an unrelated change.

**Change.** Stopped Docker and containerd, purged the packages, deleted their data directories, the package source and its key. The next `apt update` showed no Docker source. Then the upgrade, with `apt full-upgrade` so the new kernel package came in, and the old kernel kept in the boot menu as the fallback. After the reboot, the FORWARD policy read ACCEPT, every guest came back, both GPUs were bound to vfio-pci, and both drove their VMs on the new kernel.

**Lessons.** Audit a hypervisor's package sources against your notes before upgrading it. Check `dpkg -l` for anything that belongs in a guest. Keep Docker in guests.

## 23. An exit node bought for its IP, and an SSH rule that did nothing

**Context.** I wanted a Norwegian IP for Norwegian TV that is limited to Norway, for language study. My first reason was the direct undersea links from the UK to Norway. That reason was wrong: an exit node is where traffic leaves, so for anything in the UK a Norwegian exit is a detour. The UK exit stays the daily default.

**Choosing the provider.** The first offer I found was a VPS site named after the country. Its page named a third-party company, ran orders through another company's client area, sat on a Norwegian datacentre operator's servers, and contradicted itself on location, cores and refunds. I bought direct from the datacentre operator instead.

**The test before the build.** An IP lookup site proves geolocation only. Streaming services also check datacentre ranges, so the go/no-go was a programme that plays only in Norway. It played, so I kept the server.

**Build and hardening.**

- Tailscale installed and advertised as an exit node under the existing exit-node tag. The image had no `curl`, so the install script failed first and the next pasted line ran anyway, harmlessly.
- Password and keyboard-interactive SSH off, then public TCP 22 dropped at the provider's firewall rather than on the host, so a host-side mistake cannot lock me out. A port test from home then timed out, as intended. The way back in is the provider's console, with the root password in my password manager.
- `unattended-upgrades` installed. It did not switch itself on: the APT setting read empty until I wrote the config by hand and read it back.

**The SSH rule.** My policy had a Tailscale `ssh` rule to the exit-node tag, recorded for weeks as probably inert because no network grant reached that tag. `tailscale ssh` to the new node timed out with the node online, which confirmed it. I added one narrow grant, members to the exit-node tag on TCP 22 only. After that, Tailscale SSH opened a root shell on the new node and on the UK node. Tailnet traffic arrives inside WireGuard over UDP, so the provider firewall rule on TCP 22 does not affect it.

**Lessons.** Pick an exit node's location for the IP it gives you. Test the purpose against the service itself before building out. A Tailscale `ssh` rule needs a network grant to the same destination. Close public SSH at the provider, and keep a console route in.

**Since then.** The Finnish exit node was retired a week later. Before deleting it I checked its peers: the only active one was my own SSH session, and nothing had used it for days. The policy file and DNS held no reference to it. Then the node came off the tailnet and the server was deleted. Three exit nodes remain. Tailscale on the older exit nodes still needs updating.

## 24. A Platform SSO join refused by a setting I changed the day before

**Symptom.** The replacement Mac enrolled in Intune, then Platform SSO registration failed with "Registration failed and will automatically retry in a few minutes". The Mac mini had registered the same way the day before.

**What settled it.** The Mac's dialog gave no reason, so I went to the Entra audit log and filtered on the Device Registration Service. One failed Register device entry, for my daily account: "Administrator policy does not allow user ... to device join". That pointed at Entra's Device settings, where "Users may join devices to Microsoft Entra" read Selected, with only the admin account in it.

**Cause.** I had narrowed that setting during the admin account split the day before and not recorded it. My notes still said All. The Mac mini's registrations ran before the change, so the pilot never hit it. Platform SSO joins the Mac in the signed-in user's name, so the daily account needs join rights.

**Change.** A group holding the daily and admin accounts, set as the only entry in that setting. Not All, because All includes the break-glass accounts, which every Conditional Access policy excludes, and nothing should be joining devices as them. Not the Platform SSO user group either, so SSO targeting and join authority stay separate. The retry then joined the Mac.

**Lessons.** When a Platform SSO registration fails, read the Device Registration Service audit log before guessing. Record every tenant setting changed along the way, including ones changed in passing. This one surfaced a day later on a different machine.

## 25. An API key that synced to every device

**Context.** My Obsidian vault syncs through Syncthing, with the NAS as the hub. The vault's Khoj plugin connects to my self-hosted Khoj instance with an API key. The new Mac needed its own key.

**The wrong conclusion.** The old Mac connected to Khoj with an empty key field in the plugin's settings file. I read that as "the plugin keeps the key per device" and did not test it. I created a key for the new Mac and entered it. The plugin wrote the key into its settings file inside the vault, and Syncthing carried it to every vault device, the NAS, and from the NAS towards the offsite backup. I found it by checking the file afterwards, with a count and a length, never the value.

**Containment, then rotation.** Rotating first would only have spread the new key the same way. So the order was:

1. An ignore pattern for that one file on the NAS hub, then on both Macs. Syncthing does not sync ignore files between devices, so each device needs its own.
2. Rescan everywhere and confirm Up to Date, with "Reduced by ignore patterns".
3. Delete the key on the Khoj server and create a new one under the same name, in one step.
4. Enter the new key on the new Mac only, then prove it stayed there. The settings file hashed differently on the two Macs, and the old Mac's copy held the revoked key.

The leaked key still sits in each old copy of the file and in backups. Ignored files are left on disk, not deleted, and backups are not rewritten. It is revoked, so every copy is dead. The key never went into a chat.

**Also found.** Eleven Syncthing conflict copies of plugin settings files, which sync to every device like any other file. I diffed each against the current file before deleting it: the plugin lists matched, and one minor setting had been lost.

**Lessons.** Prove where an app stores a secret before entering one on a synced device. Plugin settings in a synced vault are shared state, so exclude per-device files before the first device writes them. Contain first, then rotate.

## 26. A server-side connector blocked by a device policy

**Symptom.** A Microsoft 365 connector for an AI assistant, linked to my daily account, failed every sign-in with AADSTS530003, device required to be managed.

**What the sign-in log showed.** A non-interactive sign-in to Microsoft Graph with no device, OS Linux, client app Browser, and a Node.js identity library as the user agent, from the vendor's network. The connector redeems tokens on its own servers. My compliant-device policy applied, because Graph carries Office 365 audiences and Linux is in the policy's platform list, and it failed, because a server process can never present a device.

**The first fix considered was wrong.** Excluding the connector's app from the policy. Conditional Access targets the resource the token is for, not the client asking for it, so that exclusion would have changed nothing. It was dropped before anything was saved.

**Design.** Three constraints: the exclusion as narrow as Microsoft allows, nothing weakened for the admin account, and a control on whatever path it opens.

1. Move the admin account first. A new policy requires a compliant device for the admin account on all resources. I proved it with an admin sign-in before touching the original policy.
2. Exclude only the vendor's published egress range from the original policy, as a named location marked not trusted. Not the app, the user or the platform. The admin account is excluded from it too, now that it has its own.
3. A compensating policy on that range only, for the daily account only: require MFA, with a seven-day sign-in frequency. Report-only first, then on.

**Evidence.** Before: the connector failed under the device policy. Report-only: the connector signed in, the device policy read not applied because of the location exclusion, and the new policy read report-only success. Enforced: success, with the MFA and sign-in-frequency controls satisfied.

**Proving enforcement needed a fresh token.** After switching the policy on, the next log export held no connector entry at all. That was not a pass. Conditional Access is evaluated only when a token is issued, and the connector was running on a cached one. A fresh call the next morning produced the enforced result.

**Residual risk, recorded.** The excluded range is shared by every customer of that vendor. A stolen refresh token replayed from it would skip the device check. The compensating policy limits that with the MFA claim and the seven-day re-authentication. It does not stop a replay inside that window. In a client tenant this would need a written risk decision from the data owner, and a scheduled check of the vendor's published range.

**How the consent was granted.** The audit log's portal view showed nothing, so I exported it. The export held the record. My daily account had granted organisation-wide admin consent sixteen days before the connector's first sign-in, while it still held Global Administrator. It was the same pattern as the [admin consent incident](m365-endpoint-labs.md#tenant-administration-incident-an-accidental-admin-consent), and it happened before I split the admin account out. The connector registers two enterprise apps, each with its own grant. I set Assignment required on both and assigned only the daily account. That restriction turned out not to bind administrators ([case study 28](#28-a-deny-test-that-passed-the-wrong-way)).

**Not yet shown.** The compensating policy refusing a token without an MFA claim, and the seven-day re-authentication happening in practice.

## 27. Wake-on-LAN that my notes said was on

**Symptom.** The host never woke from power-off. It had been an open fault for three weeks, and the main suspect, a forced NIC link speed, had already been ruled out.

**What I checked, in order.**

- **Link in standby.** With the host off, the switch port and the board's port both showed link lights. So the NIC kept standby power, and the firmware's power-saving mode was not cutting it.
- **The sender.** The wake command printed the right MAC and the current broadcast address. The host stayed off.
- **The wire.** A packet capture on another wired Mac on the same network caught a 102-byte UDP packet to the broadcast address on port 9, from the NAS. That is a magic packet's exact payload: six bytes of FF and the MAC sixteen times. So the packet left the NAS and crossed the switch.
- **The firmware.** The BIOS power screen read Power On By PCI-E: **Disabled**. My notes had said "WoL on" for weeks, from a source I cannot trace. Nothing pointed to a BIOS reset, since other settings made in October had survived.

**Change.** Power On By PCI-E enabled and saved, with a photo before and after. After the next normal shutdown, one wake command booted the host, confirmed in the host's boot list.

**A near-miss.** The first test plan cut power at the PSU switch. The same BIOS screen showed Restore on AC Power Loss set to Power On, so restoring power would have booted the host by itself and proved nothing. Caught before it ran.

**Side effect.** The host's catch-up backups, which start soon after a boot that follows an overnight power-off, were cut short by the test shutdown. I checked for leftover locks and partial files on the NAS, found none, and reran both jobs clean.

**Lessons.** Read the firmware setting itself before trusting a note that says it is on. Capture on the wire to split sender faults from receiver faults. Before a power-cut test, check what the board does when power returns.

**Repeated.** The second test came a day later, from my workplace over the tailnet. The host's boot list showed a normal shutdown the night before, and one wake command booted it. I waited for its catch-up backups to finish before shutting it down remotely.

## 28. A deny test that passed the wrong way

**Context.** The AI assistant's Microsoft 365 connector holds an organisation-wide grant ([case study 26](#26-a-server-side-connector-blocked-by-a-device-policy)). I set Assignment required on both of its enterprise apps and assigned only my daily account. To prove the restriction, I connected the connector as my admin account and expected a refusal, AADSTS50105.

**It connected.** The assistant read the admin account's profile and granted scopes through Microsoft Graph.

**Contain first.** Before reading anything, I disconnected the connector, revoked the admin account's sessions, and reconnected it as the daily account. A Graph call through it then returned the daily account.

**Why assignment did not refuse.** Both apps listed only the daily account, and Assignment required read Yes on both. Microsoft's troubleshooting article for AADSTS50105 says it plainly: the assignment requirement does not apply to Global Administrators. The admin account is one. So are both break-glass accounts. My test used the one kind of account the control ignores, so it could never have shown the control working.

**Why my admin device policy did not refuse either.** The connect started in a browser on a compliant, Entra-joined Mac. Every later token on that session carried the Mac's device claims, including the ones the vendor's Linux servers redeemed. A compliant-device policy shows where a session started, not where its tokens are used.

**Change.** A Conditional Access policy that blocks the admin account from the connector's server app. Conditional Access does apply to administrators. The policy simulator lists it as applying with Block access. I have not yet repeated the connect to see it refuse live.

**Residual risk, recorded.** The break-glass accounts are Global Administrators excluded from every policy, so neither assignment nor the new block stops them. Accepted, as the recovery path. The daily account can still authorise the connector from an unmanaged machine, since no device policy targets the server app.

**Lessons.** A deny test only counts if the test account is subject to the control. Restrict administrators with Conditional Access, not assignment. When an expected failure succeeds, that is the finding: contain it, then read the logs.

## 29. A retired mailbox still trying to sign in

**Symptom.** A non-interactive sign-in export showed the NAS's old alert mailbox failing token refresh every morning at 04:00, from home, with the user agent "Synology". My notes said nothing had tried to use that mailbox for weeks, and its app grant had been deleted.

**What I checked.** The NAS's cron table had one 04:00 entry, a scheduled task. That task was an rsync job pulling from a VPS retired three weeks earlier. It failed every night, and each failure made the NAS try to send a notification through the retired mail sender, which tried its dead token.

**Change.** Deleted the task. The NAS's alerts already go through Synology's own notification service. Its last copy of the old VPS's files, 3 MB, is still to be archived or deleted.

**Also caught.** While cleaning up in Entra, I nearly deleted the NAS's single sign-on app registration, which has a similar name. I stopped before saving. Check an object's app ID before deleting it, not its name.

**Lesson.** Sign-in logs for a retired account can point to a stale job on another machine. When decommissioning a server, search every machine's schedulers for jobs that call it.
