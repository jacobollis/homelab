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

## 10. A renewal task that reported Success for five weeks

The NAS certificate renewal task showed Success every day. The deploy step had been failing for five weeks, and the certificate DSM served expired. A task's status proves only that it exited cleanly.

Change: rebuilt the deploy to create a throwaway local admin for each run and delete it afterwards, so no admin password is stored, and pointed it at the local HTTP port so deployment never depends on the certificate it replaces. Verified by the certificate DSM actually serves, not the task log.

Open: the certificate expiry rule did not fire before the expiry. That is on the roadmap.

## 11. A config edit that did nothing, and a red alert lost in the noise

While rotating dead-man's switch URLs, a `sed` substitution matched nothing because the old value was typed wrong. sed exits silently when nothing matches. A `grep -o` extract of the URL looked valid inside a broken line. Alertmanager's watchdog check went red, the alert arrived among a batch of test alerts, and it went unnoticed for six days.

Changes: match on a fixed prefix rather than the full old value, grep the file after every edit, test the exact value the service will use, and end every monitoring session by checking that Healthchecks and the Alertmanager alerts page are green or explained.

## 12. A stale device object that still claimed to be compliant

After the Mac mini was factory reset and re-enrolled, Entra held two device objects for it. The stale one still read compliant and managed, left over from the earlier enrolment. Intune mapped only to the live one.

An orphaned object that claims compliance is a risk if anything ever authenticates as it. Safe sequence: disable the stale object, sign in from the Mac and confirm the sign-in log shows the live device ID passing CA001, then delete the stale object. Entra deletes by object ID, not device ID, which matters when two objects share a display name.
