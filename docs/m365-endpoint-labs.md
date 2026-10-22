# M365 and Intune labs

A Microsoft 365 Business Premium tenant with one licensed user, plus a Windows Enterprise E3 licence bought for the Remediations lab and ended once the lab was done. Business Premium covers Intune Plan 1, Entra ID P1, Autopilot and Defender for Business.

I reactivated a dormant tenant rather than starting fresh. The custom domain can only be verified in one tenant, and year-old leftover objects turned out to be good lab material.

Every lab follows the same pattern: record the state as found, change one thing, prove the result on the device and in the portal, and keep a negative control where one is possible.

## Status

| Lab | Status |
|---|---|
| Tenant baseline and break-glass accounts | Complete |
| Windows Autopilot, user-driven, Entra joined | Complete |
| Conditional Access, require compliant device | Complete, enforced |
| macOS enrolment, compliance, SSO extension, Defender | Complete |
| macOS corporate enrolment with Platform SSO on a second Mac | Planned, from late October |
| Android Enterprise fully managed, compliance, Defender | Complete |
| iPhone app protection without enrolment | Complete, enforced |
| Windows compliance and BitLocker | Complete |
| Win32 app packaging and supersedence | Complete |
| Update ring | Complete |
| Web content filtering, Edge and Firefox | Complete |
| RHEL 10 enrolment, custom compliance, Conditional Access | Complete, VM since deleted |
| Remediations | Complete |
| Separate admin account, daily account with no admin roles | Complete |
| Purview: sensitivity label, DLP, retention, eDiscovery | Complete except retention label, which is still propagating |

## Tenant baseline

- Found and revoked a stale OAuth grant that let a NAS app send mail as the Global Administrator. Replaced it with a sign-in-blocked shared mailbox.
- Created two break-glass Global Administrator accounts, excluded from every Conditional Access policy. My notes had both on the `onmicrosoft.com` domain. In October I found one was on the custom domain, so a domain problem could have taken out both, and renamed it.
- Changed "Mark devices with no compliance policy assigned as" from Compliant to **Not compliant**. Before the change, an enrolled Mac with no policy showed a green Compliant and would have passed a require-compliant gate on nothing.
- Set Android device administrator enrolment to Block. It is a deprecated mode.

### Break-glass accounts: two real gaps found

When I verified the break-glass setup rather than trusting my notes:

1. One Microsoft-managed policy, Block legacy authentication, had no exclusions. My earlier record said both accounts were excluded from everything. Fixed.
2. **Neither account had an MFA method registered.** Microsoft's mandatory MFA for admin portals is not a Conditional Access policy and cannot be excluded. Both accounts, which exist only to survive a lockout, could not have signed in to the admin portals. Fixed the same day and proven with a live sign-in from each.

## Windows Autopilot

Windows 11 Pro on a Proxmox VM, registered with Autopilot, deployed user-driven, Entra joined and Intune enrolled, from an empty tenant configuration to a verified device in one day.

VM spec: q35, OVMF with pre-enrolled Secure Boot keys, vTPM 2.0, SATA disk and an e1000e NIC so Windows Setup needs no extra drivers. The SMBIOS serial is set before first boot, because the hardware hash derives from it and changing it later invalidates the registration.

Tenant objects:

- Dynamic device group keyed on the Autopilot group tag, `(device.devicePhysicalIds -any (_ -eq "[OrderID]:AP-Lab"))`. The common `-startsWith "[ZTDId]"` rule would catch every Autopilot device in the tenant. Group tags are how fleets are segmented.
- Deployment profile: user-driven, Entra joined, licence and privacy pages hidden, **user account type Standard**, device name `%SERIAL%`.
- Enrollment Status Page showing progress, 60-minute timeout, block until apps and profiles install, Windows updates off because of the slow WAN link.
- Company branding on the sign-in page.

Hash capture used `Get-WindowsAutopilotInfo -Online` from Shift+F10 at OOBE, with a Graph session opened by device code first. The script raises a Web Account Manager dialog that fails with error `0x80192ee7`. It is not fatal. `dsregcmd /status` afterwards confirmed nothing had half-registered.

**Finding: the profile's user account type overrides the Entra local admin setting.** To make this a real test, I first set "Global administrator role is added as local administrator on Entra join" to No, since my account is a Global Admin and would otherwise get admin by role. With the Entra setting "Registering user is added as local administrator" left at All, the enrolling user still came out as a standard user. `net localgroup Administrators` listed only the disabled built-in account.

Verified on the device with `dsregcmd /status` (Entra joined, TPM-protected, PRT issued, Windows Hello provisioned) and in both portals.

## Conditional Access

### Removed an inert policy

An existing "Compliant Devices" policy from 2025 had **no target resources**, so it evaluated nothing. It had sat in report-only for fourteen months looking like a control. It also excluded every non-Windows platform. I deleted it rather than patch it.

### CA001: require a compliant device for Office 365

- All users, excluding the two break-glass accounts and the NAS service mailbox. The service exclusion is load-bearing: the NAS signs in from a device that will never be compliant.
- Target: Office 365, not All resources. Requiring a compliant device for all resources includes the Entra and Intune portals, so one mistake could lock me out of the tools needed to undo it.
- Platforms: Windows, macOS, Android and Linux. iOS is handled by CA002.
- Report-only first, then enforced.

Evidence, captured with the policy enforced:

| Device | Browser | Device state | Result |
|---|---|---|---|
| Mac mini | Edge | Managed, compliant | Allowed |
| Windows lab VM, before a Windows compliance policy existed | Edge | Managed, not compliant | Blocked, error 53000, "Check compliance" offered |
| Same Windows VM, after the compliance policy | Edge | Managed, compliant | Allowed |
| MacBook, deliberately unenrolled | Safari | Unregistered | Blocked, error 530003 |
| RHEL 10 VM with firewalld stopped | Edge | Managed, not compliant | Blocked, error 530002 |

The Windows rows are the cleanest before-and-after: same device, browser, user and app, and one variable changed.

I keep the MacBook unenrolled as the negative case. The macOS block page offers a Continue button that enrols the device, which would destroy the test.

**Limit of the macOS claim.** An unmanaged Mac is blocked because it cannot present a device identity, not because it is evaluated and found non-compliant. The Windows row shows real evaluation.

### CA002: require app protection on iOS

All users except break-glass and the service mailbox, Office 365, iOS only, browser and mobile apps. Grant: require app protection policy alone. I did not pair it with "Require approved client app", which Microsoft is retiring, because "require one of" would weaken the policy to whichever control is easier.

## macOS

- Mac mini enrolled through Company Portal, Corporate ownership via a corporate device identifier added before enrolment. User-approved and supervised. On macOS 11 and later, user-approved enrolment is supervised. What ADE adds is Setup Assistant enrolment and a non-removable profile, and this Mac has neither, so a local admin could remove management. I describe it as "user-approved, supervised, removable".
- Compliance policy `macOS Default`: SIP, minimum OS, firewall, Gatekeeper, FileVault. Failure path tested by turning the firewall off.
- **Finding: macOS compliance settings also enforce.** After the policy was assigned, firewall and Gatekeeper profiles appeared on the Mac, and they are not listed in the device's configuration report. The firewall failure test only worked because it ran before the enforcement profile arrived.
- Defender for Endpoint onboarded through two Intune custom profiles: the onboarding package and Microsoft's combined permissions profile. Verified with `mdatp health`.
- Apple MDM push certificate on a dedicated Apple Account, with a renewal reminder a month before expiry. It is renewed, never recreated. A new certificate orphans every enrolled Apple device.

### The SSO extension finding

The Mac was enrolled, managed and compliant in Intune, and every Entra sign-in from it showed Device ID blank, Compliant No, Managed No. Intune knew the device. Entra saw an anonymous browser. Nothing in either portal flagged the gap.

Device-based Conditional Access on macOS needs the Microsoft Enterprise SSO plug-in, which arrives only as a configuration profile you deploy on purpose. I deployed a Device features profile with SSO app extension type Microsoft Entra ID, the Edge bundle ID, and `browser_sso_interaction_enabled` and `disable_explicit_app_prompt` set to 1 as integers. Same Mac, same browser, same policy: the sign-in then carried the device ID and showed Compliant Yes.

Firefox on macOS never presents a device identity, so a Firefox test proves nothing about the device. Microsoft's block page suggests Safari by name, which is the clue.

### Next: Platform SSO on a replacement Mac (planned)

A replacement MacBook arrives in late October and takes over as my git machine. Nothing below is built yet. The design:

- Corporate ownership from a serial registered before first power-on, then Company Portal enrolment. No ADE, for the reason in [decisions](decisions.md#the-replacement-mac-is-enrolled-without-apple-business).
- Platform SSO through a settings catalog policy, Secure Enclave method, on its own group. That group is excluded from the Mac mini's Device features SSO profile, to avoid Microsoft's error 10002 for more than one SSO extension payload.
- FileVault with the recovery key escrowed to Intune from day one, which the Mac mini never had.
- A local admin account for elevation and a standard daily user.
- **Prerequisite, met in October:** my daily account stops being a Global Administrator first ([separate admin account](#separate-admin-account)). A separate cloud-only admin account takes the role. Otherwise the Mac's sign-in identity would be a Global Administrator, which is the root cause of the [admin consent incident](#tenant-administration-incident-an-accidental-admin-consent).

Evidence to capture: enrolment status, the Platform SSO registration, the Entra join type, one SSO extension profile and no 10002, the escrowed key, compliance, Defender health, and a Conditional Access sign-in showing the device as compliant and managed.

The outgoing MacBook was the tenant's unmanaged negative case for the compliant-device policy. That evidence is already captured. Afterwards, the work desktop, an unmanaged Linux machine inside the policy's platform scope, shows the block on demand.

## Android Enterprise

- Managed Google Play bound through the Android Enterprise sign-up, which creates a managed Google domain at no cost. Google's flow redirects to Workspace sales pages repeatedly. None of them are required.
- Samsung Galaxy S25 Ultra enrolled as **corporate-owned, fully managed** by QR code after a factory reset. Token revoked after enrolment.
- Compliance policy: Play Integrity basic and device integrity, minimum OS, numeric complex password with a minimum length, encryption, and later Defender machine risk at Low or below. The password type is set explicitly, because "Device default" does not evaluate password compliance at all. Failure path tested by removing the screen lock.
- Apps approved in Managed Google Play and assigned, some Required and some Available.
- Defender for Endpoint onboarded. Its web protection is disabled by app configuration (`antiphishing` and `vpn` set to 0) because it runs as a local VPN and Android allows one, which conflicted with Tailscale. Antivirus stays on. Tailnet-wide NextDNS filtering is the compensating control.

## iPhone: app protection without enrolment

The iPhone is a personal phone. It is not enrolled and has no MDM profile. Management is on the apps.

`APP001` covers Outlook, Teams and Edge:

- Org data only to managed apps, saving only to OneDrive or SharePoint, paste out restricted, backup blocked, encryption required.
- Web content transfer restricted to Edge, so links from Outlook and Teams open inside the boundary.
- Six-digit app PIN, simple PINs blocked, biometrics allowed with a PIN recheck.
- Jailbroken devices blocked, offline wipe after 90 days.
- Third-party keyboards and org data notifications deliberately left allowed. Both are common reasons users demand a BYOD policy be removed, and a control that gets removed protects nothing.

Scoping uses a **Managed apps** assignment filter, `(app.deviceManagementType -eq "Unmanaged")`. I moved to a filter after finding that **editing an iOS app protection policy reset its device-type targeting to all device types and saved it that way**, with only an info banner. Read from the policy's properties, not assumed from the wizard. A filter has nothing for an edit to reset.

Evidence:

| Test | Result |
|---|---|
| Policy applied without enrolment | App protection status shows all three apps as Management type Unmanaged, and Intune shows zero iOS devices |
| Copy from Outlook into a personal app | Refused |
| Native iOS Mail | Blocked, error 53009, Conditional Access Failure in the sign-in log |
| Safari to Office 365 | Blocked |
| Outlook and Edge | Allowed throughout |

## Windows compliance and BitLocker

`Windows 11 Default`, assigned to the Autopilot device group: minimum OS build, firewall, TPM, antivirus, antispyware, Defender antimalware, real-time protection, then encryption.

Left out on purpose, each for a reason: Device Health attestation settings (unreliable on a virtual TPM), password settings (unreliable with a Windows Hello PIN), Defender signatures up to date (fails on a fresh VM for reasons unrelated to posture).

On first evaluation the firewall returned **Error, not Noncompliant**. Error means the device could not evaluate the setting. I checked ground truth with `netsh advfirewall show allprofiles state` (all on), resynced, and it cleared with no policy change. Removing the setting to get a green result would weaken the control to fix a reporting problem.

### BitLocker: the premise failed, and that became the finding

I planned to show a device arriving unencrypted, failing compliance and being encrypted silently by policy. The device was already encrypted. The Entra audit log showed a BitLocker key escrowed in the signed-in user's context before any encryption setting or policy existed. Windows 11 automatic device encryption had done it.

I built the silent BitLocker policy anyway: XTS-AES 256 for OS and fixed drives, AES-CBC 256 for removable, standard user encryption allowed, every startup PIN or key option set to Do not allow, and encryption blocked until the recovery key is escrowed.

Then I checked the drive. The device has only a standard user, so I ran `manage-bde -status` through an Intune platform script as SYSTEM that writes its output to a public folder.

| Source | Reading |
|---|---|
| Policy per-setting status | All 8 settings Succeeded, including the encryption method |
| Encryption report | Encrypted |
| `manage-bde` on the device | **XTS-AES 128**, protection on, TPM and recovery password protectors |

**Intune reported success while the drive ran a weaker cipher than the policy required.** The encryption method applies only at the moment of encryption, and automatic encryption had already used the default. Succeeded means the configuration service accepted the value, not that the drive matches it. The real-fleet fix is ordering: the BitLocker policy has to land during ESP, before automatic encryption starts. I did not re-encrypt the lab VM.

## Win32 apps

PowerShell 7 packaged as a Win32 app with the Microsoft Win32 Content Prep Tool, then superseded by a newer version.

- Hashes and Authenticode signatures checked on the device that used the files, not on the Mac where I first downloaded copies.
- MSI product codes and upgrade code read from the files with the WindowsInstaller COM object. Both versions share an upgrade code.
- Install command with Microsoft Update disabled for PowerShell, so it stays under Intune's control. Detection by product code.

**Finding: the first deployment passed detection for an install it never performed.** The report had no exit code and no download time. The MsiInstaller event log showed SYSTEM had installed the same version nine days earlier. The installer was a forgotten line-of-business app for the same product, assigned to the same group. Win32 detection by product code cannot tell who installed a product. I deleted the LOB app.

The supersedence step then ran cleanly: not found, download, install as SYSTEM, exit code 0, detected. One registry entry remained, the newer version, so the shared upgrade code drove an in-place upgrade.

Takeaways: never deploy one product through both the LOB and Win32 channels, and validate a Win32 deployment with the install evidence, not only the detection result. The Intune Management Extension log, the MsiInstaller events and the MDM diagnostics log are all readable by a standard user.

## Update ring

`Ring 0 - Pilot`: zero deferral, deadlines of 7 days for feature and 2 for quality updates, pause disabled, auto reboot before deadline on.

- Delivery proven in `HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Update`, where every ring value appears with the Intune enrolment as the winning provider.
- **Finding:** Windows 11 26H2 had started installing about six hours before the ring existed. An ungoverned tenant was already taking feature updates on Microsoft's schedule. The ring only governed the restart, and with zero deferral plus auto reboot it asked for a restart within an hour, outside active hours. That is why production rings defer.

## Web content filtering

Defender for Business web content filtering and custom indicators, enforced in Edge and Firefox on the Windows lab VM.

- Edge enforces through SmartScreen, which I locked on by policy so users cannot bypass it.
- Every other process, Firefox included, is enforced by network protection, set to block mode.
- Test from a non-Edge process with `Invoke-WebRequest` against Microsoft's test URL, then event 1126 in the Defender Operational log, whose process field shows which process was blocked.
- Category block (Gambling) and domain indicator blocks evidenced in both browsers. The block pages differ by control, so the page shows which one fired.

### Firefox and Encrypted Client Hello

Network protection reads the hostname from the TLS ClientHello. With ECH, it only sees the outer public name.

- Firefox negotiated ECH on this network intermittently, with DNS over HTTPS off. Turning off DoH does not turn off ECH.
- **Before**, with DoH on and no policy: every 1126 event recorded the outer name, `public.tls-ech.dev`.
- **After** deploying the Mozilla ADMX policy "Disable Encrypted Client Hello" through Intune, same DNS path and target: every event recorded the real host, `tls-ech.dev`.

What the evidence does not support: a blocked page actually loading through ECH. My first test site's outer name sat under the blocked domain, so both states were blocked. I do not claim a demonstrated bypass.

Two side findings:

- My ISP's resolver substitutes its own answer for Firefox's default DoH hostname, which breaks Firefox DoH. Pinning a bootstrap address fixed it for the lab.
- **A standard user can override a threat-intelligence block in one click** from the Windows Security toast, with no credentials. The override left no event in the device log, and on Defender for Business there is no device timeline to see it centrally. The incident in the portal still read Blocked. Category and indicator blocks offered no override.

## Linux: RHEL 10

A RHEL 10.2 VM with LUKS2 full-disk encryption, enrolled through the Microsoft Intune app.

- I installed the dependency chain by hand, mirroring Microsoft's installer script, so each piece is explainable. On RHEL 10 the Intune app needs EPEL for 13 of its 18 dependencies.
- The Intune app replaces the authselect profile and inserts `pam_intune.so` into the PAM stack. I read the stack order to confirm it cannot bypass the local password check.
- Microsoft documents RHEL support without naming a hypervisor. I describe a Proxmox guest as a supported OS on an undocumented hypervisor.

`Linux Default` compliance, built one setting group at a time so every state change had one cause: distribution and minimum version, encryption, password policy, custom compliance.

**Finding: the password check measures the user's actual password, not the configured policy.** `pam_intune` records the length and character classes of the password at each authentication, and the agent compares that with the policy. I made the OS enforce 14 characters three different ways and Intune still reported the old length each time. A password change plus one authentication made it compliant. The agent also reports the real password length to the service.

**Custom compliance:** a POSIX shell discovery script and a rules file checking that the Cockpit socket is disabled and firewalld is active. The device runs the script and uploads raw output. The service evaluates the rules. Both rules tested failing and passing.

CA001 was extended to Linux, and both the allow path and a block path (firewalld stopped, error 530002 in Edge) are evidenced in the sign-in log.

The VM was deleted after the lab, with its Intune and Entra records removed first.

## Remediations

Remediations is not licensed by Business Premium. It needs Windows Enterprise E3 or E5 per user. The portal gates it behind a tenant attestation checkbox. Ticking it without the licence would be a false attestation, so I bought a Windows Enterprise E3 licence for the lab.

Package: PowerShell detection and remediation for one per-user setting, whether File Explorer hides file extensions. Runs as the signed-in user, hourly, on the Autopilot lab device.

- On-demand run proven in the device log: detection found drift, remediation fixed it, post-detection passed.
- **Scheduled runs fixed drift unaided three times.** The first had happened two weeks earlier and was never read, because the session ended before the hourly run. The Intune Management Extension's log still held it, so I counted that day's lines before repeating the test. Two fresh drift tests then fixed in under an hour each, proven by the log, the registry and the portal's Device status with pre- and post-remediation output.

| Evidence | Result |
|---|---|
| Device log, run after the drift | Detect found the drift, remediation fixed it, post-detect passed, exit codes 1, 0, 0 |
| Registry and File Explorer | Value back to the compliant setting, extensions shown |
| Portal, Device status | With issues, Issue fixed, pre-remediation output showing the drift, post-remediation output showing it fixed |
| Portal, overview tiles | With issues 1, Issue fixed 1 |

Findings:

- **Device status shows only the latest uploaded result.** An hour after a fix it read Without issues and Not run, with no trace of the fix. Take the screenshot inside the hour.
- **The agent appears to upload a result only when it changes.** Five unchanged hourly results produced no uploads, and a scheduled fix identical to the on-demand fix before it never reached the portal. Read from one device's log, not documented.
- **The daily trend chart is not evidence.** It showed zero fixes on both days with fixes.
- **The hourly schedule drifts later on every run,** by seconds to about two minutes. Time a drift test from the last logged run.

Limits: one device and one user, user context only, unsigned scripts, no failed run to show failure handling.

**Wind-down.** The package's assignment was removed and kept as evidence, the licence attestation withdrawn, and the E3 set to end at its term. One mistake: I removed the E3 before confirming the Windows Business plan was back on my account, the reverse of the planned order. The admin centre shows that plan ticked, but the user's licence record never changed. Proving a licence change from `licenseAssignmentStates` in Graph, not the admin centre panel, is how I found it. It is on the roadmap.

## Purview and Microsoft 365 apps (AB-900 study labs)

- **Sensitivity label** with encryption and a footer. Applied in Word, emailed to an outside mailbox, and refused in the browser. Limit: the web viewer cannot open IRM files for anyone, so that is not an access-control result. A desktop test as an outside identity is still to do.
- **DLP** for UK financial data on Exchange and OneDrive, blocking external sharing. A test email produced the non-delivery report, user notification, incident report, alert and Activity explorer events. Note: DLP incident reports quote the sensitive data in full, so their recipients must be a small trusted group.
- **Retention** policy and a published retention label. The label had not reached OneDrive at the time of writing. Microsoft allows up to seven days.
- **eDiscovery.** Global Administrator does not grant content search. It needs the eDiscovery Manager role group, and every search raises a default alert. Both are safeguards by design.
- **Compliance Manager** read 62 percent overall, but customer-managed controls stood at 12 percent. I quote the customer-managed figure.
- **SharePoint sharing was at its most permissive** as found: Anyone links, Edit by default, no expiry. I tightened it to existing and new guests, Specific people links and View by default. Nothing in the portal flagged the original state.
- Exchange, SharePoint and Teams objects created and compared: distribution list versus Microsoft 365 group, team site versus communication site, a private channel and its separate site.

## Tenant administration incident: an accidental admin consent

A password manager filled my Global Administrator account into a third-party app's sign-in, and I accepted the consent prompt. Because the account is a Global Administrator, that consented for the whole organisation, with delegated file and site read and write permissions.

- The audit log showed the service principal and grants created in the same two seconds.
- The sign-in log showed the token request failed Conditional Access, because the device was not compliant. The app never used the grant.
- I deleted the enterprise application, which removed the grant, then set user consent to **Do not allow** and turned on admin consent requests.

The lesson: consent and token issuance are separate steps. Conditional Access contained the damage, but it cannot stop the consent. The real control is not signing in day to day with a Global Administrator account, which I have since put in place: [separate admin account](#separate-admin-account).

## Separate admin account

Administration now runs from a cloud-only, unlicensed admin account with its own MFA, used from a separate browser profile on the managed Mac mini. My daily account holds no admin role. It was also a prerequisite for the replacement Mac, whose Platform SSO registration uses the daily account.

Order of work: create the account and prove it in every admin portal, move what depended on the old admin, check the break-glass accounts, then remove the roles. Removing roles first would have left nobody to fix a mistake.

| Check | Result |
|---|---|
| Admin account in Entra, Intune, Defender, Purview and the Microsoft 365 admin centre | All open |
| Both break-glass accounts, from a private window with no device identity | Both sign in, and every Conditional Access policy excludes them |
| Daily account after the roles came off | Admin centre refused, Intune shows no admin access, Outlook still works |

Findings:

- **The SSO extension lends the managed Mac's identity to a second account.** The Mac was registered by my daily account, yet the admin account's sign-ins from the same macOS user carried the Mac's device ID as compliant and managed. So the admin account passes the compliant-device policy from that Mac, and would fail it from an unmanaged one.
- **The Microsoft 365 admin portal is outside the compliant-device policy, but the Office 365 token it requests is inside.** The sign-in log showed the policy not applied to the portal resource and applied, and passed, to the Office 365 Portal token in the same session. That also corrects my reading of an earlier Firefox block: it came from the Office 365 resource, not the portal app.
- **Why that matters.** Entra, Intune, Defender and Purview sit outside Office 365, so a device falling out of compliance cannot lock the admin out of the tools that fix it. That was the design reason for targeting Office 365 rather than all resources. Now I have sign-in evidence for it.
- **Two records were wrong.** Graph Explorer's grant, recorded as consent for my account only, was admin consent for the whole organisation. I deleted its enterprise application. And my daily account held Security Administrator as well as Global Administrator, which I had never written down. Both roles came off.
- **What moved.** The admin consent reviewer moved to the admin account. The eDiscovery role group is now empty, to be filled only when a search is needed. DLP notices stay on the daily account, because the admin account has no mailbox.

Not done yet: a passkey on the admin account, since I have not checked whether the authentication methods policy allows one.
