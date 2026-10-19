# Publishing LabLedger in the Microsoft Store

Apps installed from the Microsoft Store are signed by Microsoft, so Windows
Smart App Control and SmartScreen trust them. Every GitHub build produces
`LabLedger-Store-<build>.msix`, the file you upload to the Store.

## One-time setup (about 20 minutes)

1. **Create a free developer account.** Go to
   <https://storedeveloper.microsoft.com>, choose *Individual developer*,
   sign in with your Microsoft account and verify your identity (ID document
   and selfie). Individual accounts are free.
2. **Reserve the app name.** In Partner Center open *Apps and games → New
   product → MSIX or PWA app* and reserve **LabLedger** (or another name if
   it is taken).
3. **Copy the product identity.** Open the new product, then *Product
   management → Product identity*. Note three values:
   - *Package/Identity/Name* (looks like `12345YourName.LabLedger`)
   - *Package/Identity/Publisher* (looks like `CN=ABCD1234-…`)
   - *Package/Properties/PublisherDisplayName* (your publisher name)
4. **Give them to GitHub.** In the repository open *Settings → Secrets and
   variables → Actions → Variables → New repository variable* and add:
   - `MSIX_IDENTITY_NAME` = the Identity Name
   - `MSIX_PUBLISHER` = the Publisher (including `CN=`)
   - `MSIX_PUBLISHER_NAME` = the Publisher display name
5. **Run a new build.** Actions → *Build* → *Run workflow*, or push any
   change. The release now contains a Store package with your identity.

## Each submission

1. In Partner Center open the product and choose *Start submission*.
2. **Pricing and availability:** Free (or your price), markets: all or
   Liberia only.
3. **Properties:** category *Productivity* or *Business*; tick that the app
   stores data on the device.
4. **Age ratings:** complete the short questionnaire.
5. **Packages:** upload `LabLedger-Store-<build>.msix` from the GitHub
   release.
6. **Store listings:** description, at least one screenshot (use
   *Win + Shift + S* on the running app), and the privacy policy URL — a
   simple page saying LabLedger keeps all data on the user's device and sends
   nothing to the developer is enough.
7. Submit. Certification usually takes 1–3 working days. After approval,
   install LabLedger from the Store on any PC — no warnings.

Updates: bump `version:` in `pubspec.yaml` if you want, let GitHub build,
then create a new submission and upload the new `.msix`. Store versions use
`major.minor.build.0`, so every GitHub build number is accepted in order.

## Notes

- The `runFullTrust` capability is required for desktop (Win32) apps. The
  Store asks why: answer "Flutter desktop application that reads and writes
  its own data file and user-chosen files (import/export)".
- Until the Store version is live you can keep using
  `LabLedger-Setup-<build>.exe` on PCs where Smart App Control is off.
