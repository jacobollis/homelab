# Lessons

Operating principles from running this estate. Each one cost me time before I wrote it down.

## Method

- **Ground truth first.** Pull live state before acting. Documented state can be wrong, not only stale. My own notes recorded a working VM's passthrough as unverified, and a riser as the wrong length.
- **Resolve drives by serial and PCI devices with `lspci`.** Device names reshuffle between boots.
- **When two systems differ and one works, test the working one.** Vary the thing you have not varied yet.
- **A test that cannot fail proves nothing.** A clean result means little unless the old state is known to fail under the same conditions.
- **A failing test rig proves nothing until a known-good part passes it.** The twin of the rule above.
- **Change one variable at a time,** even when a second suspect is in the same settings screen.
- **A diagnosis is only as sound as the platform it was taken on.** Confirm the machine underneath is healthy before blaming the software on top.
- **Read the tool's own report before forming theories.** Intune's Linux agent logged expected and actual values for every setting. I made three changes before reading it.
- **Record hardware by part number from the order, not from memory.**
- **Convert time zones before correlating logs.** A guest logging UTC and a host logging BST put an effect before its cause.
- **Save incident logs somewhere other than the failing device, and record where.**

## Monitoring

- **Monitoring must not share a failure domain with what it monitors.**
- **Probe the dependency, not only the service.** A GPU fell off the bus and every probe stayed green, because the HTTP endpoint still answered.
- **Test a false-positive theory against the data before tuning an alert.** Doing so exposed a five-week outage.
- **A task that reports Success has proved only that it exited cleanly.** Verify the outcome.
- **A Prometheus `for` timer restarts at every reload.** Expect a fresh wait when testing a new rule.
- **A systemd timer's `Condition*=` gates only the timer.** Starting the service by hand bypasses it, so a manual run proves nothing about the schedule.
- **An Alertmanager silence is temporary.** Anything meant to stay off is commented out at the rule with a dated note on what re-arms it.
- **End every monitoring session with a dashboard check.** A real red alert once hid among test alerts for six days.
- **Zero AER counters can mean AER is not collected at all.** Check the root port advertises the capability before trusting a zero.

## Change safety

- **`sed` exits silently when nothing matches.** Grep the file after every edit.
- **`pvesh set` prints nothing on success.** Follow it with a `pvesh get`.
- **A VM's hardware config applies only on a full stop and start.** A guest reboot keeps the old QEMU process.
- **Package removal scripts stop services by unit name,** whatever binary the unit actually runs. Check service status after any package operation.
- **`purge` deletes modified config files without asking.** Back them up first.
- **Read the `apt autoremove` list before confirming it.**
- **Before decommissioning a host, check what calls into it,** not only what runs on it.
- **Delete a server's DNS records before deleting the server,** or the next holder of that IP inherits your name.
- **Run multi-line command blocks one command at a time** when a session crosses hosts. Buffered input can land on the wrong machine.
- **Never paste command output back into a shell.** Any line that is a valid command will run.
- **Compose stacks need an explicit restart policy.** Without one, a reboot leaves containers down.
- **Update a script's header comments in the same edit as its logic.** A wrong comment inside the file that enforces a rule is worse than none.

## Secrets

- **A secret is compromised the moment it is pasted into a chat or ticket.** Deleting the transcript reduces exposure. Rotation is the remedy.
- **Write secrets directly into the file on the target host and verify structurally:** line count, hash comparison, a redacted print. Never echo the value back.
- **Placeholder discipline and secret discipline are the same habit.** Literal placeholder text in live config and a pasted real value both come from copying a code block wholesale instead of editing on the host.
- **A secret scanner on the repo does not cover the channel the repo was built in.** The commit hook blocks secrets in git. Nothing blocks a paste.
- **A redaction filter must match the file's syntax.** A `key=value` filter does nothing to YAML.
- **The SHA-256 of empty input starts `e3b0c44298fc`.** If two "secrets" hash to that, the grep matched nothing.

## Virtualisation and hardware

- **A passive riser caps the link at its own rating, and Auto does not know it.** Set the slot's link speed in BIOS to the cable's rating.
- **An idle PCIe link reading is not evidence of degradation.** NVIDIA cards drop to Gen1 at idle. Measure under load.
- **Map slots to root ports with `dmidecode -t 9` before changing a per-slot BIOS setting.**
- **`qm showcmd --pretty` shows what QEMU is actually told.** `qm config` is the abstraction.
- **A model must fit fully in VRAM with its context to be usable for interactive work.** Benchmarks of models that spill to system RAM do not transfer.
- **Keep Ollama's local settings in a systemd drop-in.** The installer rewrites the main unit on every upgrade.
- **On CachyOS, prefer AUR source packages over `-bin` packages** for anything linking system libraries.

## Networking

- **Change a guest's LAN IP over its tailnet address.** The SSH session survives the renumbering.
- **Tailscale ping bypasses ACL grants.**
- **A guest firewall rule does not open a port on the tailnet.** Check the grant.
- **Tagging a Tailscale device removes its member status.** Check what it currently gets as a member before tagging it.
- **Windows Firewall's `LocalSubnet` scope means the physical NIC's subnet,** not an overlay network. Scoping RDP to it to mean "Tailscale only" locked me out of a VPS.
- **An active exit node is a silent DNS variable.**
- **Recreate every DNS record before switching nameservers.**

## Microsoft 365, Intune and Entra

- **"Compliant" means something only if a policy was evaluated.** Set the no-policy default to Not compliant before building compliance-based Conditional Access.
- **Read the per-setting view, not the badge.** Policy delivery and compliance evaluation are separate steps, and the device header updates last.
- **Error and Noncompliant are different results.** Error means the device could not evaluate the setting. Fix the reporting, never by removing the setting.
- **Intune status lags the device.** Read the registry or the app's own policy page first.
- **Succeeded means the setting was accepted, not that the device matches it.**
- **A Conditional Access policy with no target resources evaluates nothing** and looks healthy in the portal.
- **An unassigned profile also looks healthy.** Check assignments first when a profile seems to do nothing.
- **Report-only results are on their own tab** in a sign-in's details, not in the list view's Conditional Access column.
- **Break-glass accounts need a registered MFA method** whatever the Conditional Access exclusions say.
- **Consent and token issuance are separate.** Conditional Access can refuse the token. It cannot stop a Global Administrator consenting for the whole organisation.
- **Global Administrator does not include eDiscovery.**
- **Autopilot name templates support `%SERIAL%` and `%RAND:x%` only,** 15 characters. Apple and Android profiles use a different syntax that looks similar enough to copy by mistake.
- **An Autopilot hardware hash comes from the SMBIOS serial.** Set it before first boot.
- **Each Shift+F10 session at OOBE starts from scratch.** Execution policy and loaded modules do not carry over.
- **A Windows console in QuickEdit selection pauses the process writing to it.** Check for `Select` in the title bar before calling a job hung.
- **Never deploy one app through both LOB and Win32 channels.**
- **The Apple MDM push certificate is renewed, never recreated.**
- **Editing an iOS app protection policy can reset its device-type targeting.** Scope with an assignment filter.
- **Firefox on macOS never presents a device identity to Conditional Access.**
- **Read admin-only state on a standard-user device with a SYSTEM platform script** that writes to a public folder. Never write secrets to it.
- **Check SharePoint and OneDrive sharing defaults on any tenant you touch.**
- **Quote the customer-managed Compliance Manager score,** not the overall figure.

## Gateway, renumber and power

- **Confirm who owns the edge device before designing around it.** My first gateway plan assumed modem mode on an ISP router that was not mine.
- **Sweep the live estate for the old subnet before a renumber, then list by name what grep cannot see.** The sweep found an NFS export that would have broken every backup, and an export that had silently broken a mount for two months. Database rows, appliance schedulers and DNS services need a check by hand.
- **Keep the old address as a second address until cleanup.** ifupdown2 takes two `address` lines and netplan takes a list. A session over the old address survives the change.
- **Statics on one switch keep working through a renumber.** Only traffic leaving the subnet stops.
- **Restart `pvestatd` along with the cluster services after a Proxmox network change.** Without it, every guest reads as unknown in the API and every guest-down alert fires.
- **A DNS rewrite can outlive the address it points at.** After the old host address was removed, the UI looked dead because a rewrite still pointed there.
- **Read the routing table before writing an "allow internet" rule behind another router.** The upstream router's subnet sits in the same zone as the internet.
- **When you stop a guest to keep it as a rollback, set it not to start at boot in the same step.** Otherwise it comes back after the next reboot.
- **A probe that cannot read a certificate is invisible to an expiry alert.** Pair every expiry rule with a probe-failure rule, and after adding a probe, check that every expected instance reports.
- **A host rebuild loses whatever certificate setup lived on the old host.** Check what each service actually serves after a rebuild.
- **A scrape job that is always down hides the next real one.** Build its exporter or delete the job.
- **Unprivileged ICMP needs `ping_group_range` or `CAP_NET_RAW`.** A systemd drop-in scopes the capability to one service.
- **Alertmanager's `group_wait` sets a floor on what ever notifies.** A test outage must outlast the rule's `for`, the group wait and a scrape interval, or it fires and resolves without sending.
- **Prove an alert by inverting it, then revert in the same sitting.**
- **A USB device plugged in before its package's udev rule existed keeps the wrong permissions.** Reload the rules and replay the add events.
- **Put a token on a host without it reaching the screen.** `read -rs` into a variable, check its length, write it with a restrictive umask, unset it, and shred the file once the tool has stored it.

## Lab VLAN

- **Never put a rollback command in the same run of commands as the checks.** A rollback pasted along with the verification steps undid a change that had passed every check. Give the rollback only when a check fails.
- **Check the prompt before pasting a test that must run on a specific machine.** A firewall test from the trusted side proves nothing.
- **Show a deny rule per protocol, not only per address.** Ping allowed and TCP blocked to the same address separates a policy decision from a routing fault.
- **A VLAN-aware Proxmox host can capture any VLAN on its trunk.** `tcpdump -nn -e -i <nic> vlan <id>` shows every sender's MAC when the gateway UI cannot.
- **`bridge vlan show` prints one line per VLAN on a full-range trunk.** Use `bridge -c vlan show dev <port>` and cap the output.
- **Firewall policy controls connections, not what the gateway announces.** An mDNS proxy on Auto reflects every network's services into every other network.
- **An empty flow view is not proof of no traffic.** Read the policy counter and capture on the wire.
- **Test an explanation one variable at a time and keep only what changes the result.** Turning the proxy off removed the reflected records but not the counter, so the proxy was a finding, not the cause.

## Untrusted zone

- **Take a fresh gateway backup at the end of any day that changes the gateway.** A backup from before a change is a rollback point, not a backup of the result.
- **Moving a Tailscale node behind a firewall zone can break its direct LAN paths, and Tailscale hides it by relaying.** Take `tailscale ping` before and after any segmentation change.
- **An allow policy into a zone whose reverse direction is blocked needs return traffic allowed.** For SMB, the mount hangs rather than failing, which is harder to read.
- **Prove an application block by its policy counter.** A spinning page looks the same as a network fault.
- **Include an allowed port in every set of deny tests,** run the same way. Without it, "blocked" could mean the test method does not work.
- **fish has no `/dev/tcp`.** Wrap TCP probes in `bash -c '...'`.
- **A catch-up backup can lock a VM you have just shut down.** Check the backup task list, wait for the job, then retry the config change.
- **Read the config of every guest a change touches, not only the one being tested.** The second desktop VM's config held several things my notes did not.

## IoT zone

- **Find out what a client actually does before writing cross-VLAN rules.** Capture its discovery on the trunk while relaunching the app, then design from that.
- **Ask an mDNS device directly when a capture comes up empty.** `dig @<device> -p 5353 -t PTR <service>.local` returns the full record, including the port the app connects to.
- **A capture on the hypervisor's uplink sees multicast, broadcast and its own traffic, nothing else.** Unicast between two other switch ports never reaches it.
- **Prove a proxy's scope both ways.** A capture on the target network for the forwarded query, and captures on every other network for anything beyond their baseline.
- **Record each network's mDNS baseline before turning a proxy on.** The gateway queries every network itself once a minute.
- **A custom block to the gateway shadows the built-in mDNS allow.** Put an explicit allow above it on the zone the proxy serves.
- **Check DHCP guarding's trusted server on every new network.** The form can pre-fill a factory address.
- **Move both halves of a paired device in one step,** and power-cycle them after changing the switch port's native network.
- **Prove a cross-zone allow with a counter the gateway cannot generate.**
- **Test a feature from a path that cannot borrow another feature's route.** AirPlay looked fine until it was tested from an app other than the speaker's own.
- **Turn Tailscale off on a test phone that accepts the LAN subnet route.** Otherwise the test may measure the tunnel, not the LAN.
- **A cold boot can be checked after the fact from the guest's persistent journal.** Match the guest's boot list to the host's, then count Xid lines per boot.

## Backups and the NAS

- **Plan a VM's backup space from the guest's used space when its filesystem already compresses.** vzdump's zstd barely shrinks data that Btrfs has already compressed.
- **A storage total in Proxmox may be a share quota, not the volume.** Read the volume's free space on the NAS itself before predicting a shortfall.
- **Mount a secondary disk by UUID with `nofail`,** so a missing disk does not stop the guest booting.
- **On DSM, a listener on port 22 with SFTP off can be the rsync service.** Its SSH transport defaults to 22. Check File Services before assuming, and prove the result from a client, since DSM ships no `nc`.
- **A Synology volume's lock icon means encryption. Check where the key vault lives.** A Local vault unlocks at boot unattended, so it protects drives that leave the box, not a stolen running unit. Keep the recovery file off the encrypted volume.
- **Check a NAS for data scrubbing on day one, not after a failure.**
- **Check Hyper Backup vault integrity only through DSM's own restore wizard.** A vault can look corrupt to third-party tools while intact.
- **UniFi's device fingerprint is a guess.** It labelled a MacBook on a private MAC as an iPhone. Identify a client by its MAC against the device's own network settings.

## Guest network

- **A UniFi zone may get its built-in rules only when a network joins it.** Read the zone again after creating the network, and plan custom rules against what appears.
- **Read the built-in rules before writing a custom one.** A planned block on the ISP router's LAN was already covered.
- **Reread the whole form when a UniFi form changes mode.** Switching an SSID off captive portal reset its security protocol.
- **Read the live port list before changing a switch port.** My notes had two ports swapped.
- **Strip the test client before testing isolation.** Quit Tailscale, and test the gateway's resolver with `dig @<gateway>` when the client has its own DNS profile.
- **An isolation test needs a positive control.** Zero replies between two guests prove nothing until the same pair answers on a network without isolation.
- **A UniFi hit counter shows where the gateway counted a packet, not which rule blocked it.** Prove a deny from the client.
- **Give a real example value in a command, never a placeholder.** A placeholder address was run as typed.

## GPU closure, updates and edit01

- **Check the kernel command line before choosing a log line as a verify gate.** With `initcall_blacklist=sysfb_init`, the `vgaarb` boot VGA line ignores the firmware's primary display setting.
- **Holding kernel meta-packages does not freeze a kernel that is already installed.** Read `uname -r` and the dpkg log before recording which kernel a test ran on.
- **A record kept across several chats can miss entries.** Gather every reading before closing a count.
- **A transitional metapackage can be the only thing keeping the real driver installed.** Mark the real package manual before removing the transitional one.
- **Audit a hypervisor's package sources before upgrading it.**
- **On Proxmox, upgrade with `apt full-upgrade`,** and confirm the old kernel stays in the boot menu as the fallback.
- **Install out-of-tree drivers with DKMS.** A `.run` install without it breaks on the next kernel update.
- **Ask the guest agent before debugging a black screen.** It separates a failed display stack from a stuck boot.
- **"Login incorrect" can mean the wrong user name.**
- **A command-not-found prompt can install packages.** Read it before answering.

## Remediations

- **Read the device log before rerunning a test whose result was never captured.** The log may still hold it.
- **Intune Remediations Device status shows only the latest uploaded result.** Screenshot within the hour after the fixing run.
- **Time a drift test from the last logged run, not the clock.** The hourly schedule slides later.
- **Prove a licence change from `licenseAssignmentStates`, not the admin centre panel.** The panel can show a change that never landed.
- **Make the change that grants before removing the one that conflicts.** Prove it, then remove.

## Separate admin account

- **Prove the new admin account in every portal before removing roles from the old one.** The other order leaves nobody to fix a mistake.
- **Read a consent grant's type on the app's Permissions blade.** A grant recorded as one user's consent was admin consent for the organisation.
- **List a user's assigned roles before removing the one you know about.** An unrecorded Security Administrator role was still there.
- **Check which domain each break-glass account is on.** One was on the custom domain, contrary to my notes.
- **Test break-glass access from a private window.** It presents no device identity, which is the case the exclusion exists for.
- **Read the sign-in log per resource.** One portal session produced one resource outside the policy and another inside it.

## Platform SSO

- **Platform SSO is assigned to users, not devices.** A design that waits on an empty device group does not work. Assign the user group and pilot on an existing Mac.
- **Under Platform SSO, the device identity goes only to the Entra account registered in that macOS user.** Give each Entra account its own macOS user.
- **A second macOS user registers through the Platform SSO prompt at login.** Company Portal sign-in there is device enrolment, and fails on a Mac that is already enrolled.
- **Platform SSO replaces the Mac's Entra registered object with a joined one.** Apps on old tokens fail until they sign in again. Wait for Intune's next check-in before treating it as a fault.
- **Intune's device page carries two IDs.** Match an Entra object only against the field labelled Microsoft Entra device ID.
- **An Office 365 compliant-device policy reaches the admin portals.** The break-glass accounts are the recovery path, not the policy's scope.
- **Export interactive and non-interactive sign-ins together.**
- **Crop the Activation Lock bypass code** from every Intune device screenshot.

## Exit nodes

- **An exit node's value is where traffic leaves, not the route to it.**
- **Prove an exit node's purpose against the service itself** before building it out.
- **Buy from the datacentre operator, not a country-named reseller.**
- **A Tailscale `ssh` rule needs a network grant to the same destination.** A timeout with the node online points at the ACL first.
- **Close public SSH at the provider's firewall,** and keep the provider's console as the way back in.
- **Check that `unattended-upgrades` is actually switched on** by reading the APT setting back.
- **A port that times out while the provider panel reads "installing" is not yet a fault.** Wait, and run a positive control on the same port elsewhere.

## The replacement Mac

- **Narrowing who may join devices to Entra can break Platform SSO for the daily account.** Scope joins to a named group.
- **Read the Device Registration Service audit log when Platform SSO fails.** The Mac's dialog gives no reason.
- **Add a Platform SSO Mac to a device group only after it has joined.** Registration replaces the device object.
- **The Intune policy summary lists only configured settings.** Read it against the list you intended before assigning.
- **Decline FileVault in Setup Assistant on a Mac Intune will manage.** On an already encrypted Mac, rotate the key so Intune holds it.
- **Check a new Mac's OS version against the compliance minimum before enrolling.**
- **Inventory local-only data before replacing a machine,** by checking what each sync tool covers.
- **Prove a pre-commit hook with a file name the repo tracks.** A gitignored test file is never staged, so no hook runs and it looks like a pass.
- **Guard every append to an `authorized_keys` file.** Test the source exists, back up the target, and check the line count after.
- **Write config files with `printf` one-liners, not heredocs pasted from a chat.** An indented closing marker is never seen.
- **Include the prompt line when pasting output from a machine with a twin.**

## Synced vaults and secrets

- **Prove where an app stores a secret before entering it on a synced device.** Test with a dummy value and grep for its length, never the value.
- **Plugin settings in a synced Obsidian vault are shared state.**
- **Set Syncthing ignore patterns before the app that writes into the folder first runs.** Ignore files do not sync between devices.
- **In a hub-and-spoke setup, add the ignore pattern on the hub and every spoke.**
- **Contain first, then rotate.** Rotating while the file still syncs spreads the new key too.
- **Syncthing conflict copies sync like any other file.** Diff each before deleting it.
- **Check a vault for executables before a new device pulls it.**
