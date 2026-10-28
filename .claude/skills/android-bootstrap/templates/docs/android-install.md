# Installing __APP_NAME__ on an Android phone

__APP_NAME__ isn't in the Google Play Store. Instead you install a small free
app called **Obtainium**, which fetches __APP_NAME__ for you and tells you when
there's a new version, like a mini app store with just one app in it.

It takes about ten minutes, once. After that, updates are a notification and a
tap.

You'll need: the phone, Wi-Fi, and about 100 MB of free space.

<!-- Optional: add emulator screenshots of each step under docs/images/android-install/
     (e.g. <img src="images/android-install/01-....png" width="300">). The words
     on the buttons below were checked on Android 16 with Obtainium 1.7.3. -->

---

## Part 1: Install Obtainium

**1. Download it.** On the phone, open Chrome (or your usual browser) and go to:

> **https://github.com/ImranR98/Obtainium/releases/latest**

Scroll down past the list of changes to the section called **Assets**. Tap the
file called exactly **`app-release.apk`** (about 90 MB). Ignore all the others.
If the browser asks whether to keep or download the file, say yes. When it has
finished, tap **Open** (or find it under Downloads in the browser's ⋮ menu).

**2. Let the browser install apps.** The first time, the phone says it isn't
allowed to install apps from this source. Tap **Settings**, turn on **Allow
from this source**, then tap the back arrow at the top left.

**3. Install Obtainium.** Tap **Install**. (If nothing appears after going back,
tap the downloaded file again.) If a **Google Play Protect** box says the app
is from an unknown developer or hasn't been scanned, tap **More details**, then
**Install anyway**. When it says **App installed**, tap **Open**.

---

## Part 2: Add __APP_NAME__ in Obtainium

**4. First-time messages.** Obtainium asks to send notifications: tap
**Allow** (that's how it tells you about updates). Then tap **Okay** on its
**Welcome** box and on its long **Note** about Google.

**5. Add the app.** Tap **+ Add** at the bottom right. In the box at the top,
**App source URL**, type:

> **https://github.com/__GITHUB_REPOSITORY__**

Leave everything else as it is (in particular, leave **Include prereleases**
switched off). Tap the **+** at the right-hand end of the box you typed in.

**6. Install __APP_NAME__.** Obtainium finds the latest version (something
like `android-0.1.0.2`). Tap **Install** at the bottom right.

**7. Let Obtainium install apps.** Just like the browser earlier, the phone
asks once. Turn on **Allow from this source**, then tap the back arrow.

**8. Confirm.** Tap **Install**. (Play Protect may appear again: same answer as
before.)

**Done.** __APP_NAME__ is now on your home screen like any other app.

---

## What an update looks like

When there's a new version, Obtainium shows a notification. (It checks by
itself in the background; opening Obtainium also checks.) Tap the
notification, or open Obtainium and tap **__APP_NAME__**: it shows the version
you have, the newer one, and an **Update** button. Tap **Update**, then
**Update** again on the phone's own question. Your app and its data stay where
they are.

---

## If something looks scary

These warnings are normal for apps that don't come from the Play Store.

- **"Install unknown apps" / "your phone and personal data are more
  vulnerable".** Android says this about every app from outside the Play
  Store. You're only allowing the browser and Obtainium, and you can switch it
  off again in Settings → Apps → Special app access → Install unknown apps.
- **Google Play Protect: "unknown developer" or "app not scanned".** The
  developer hasn't registered with Google. Tap **More details → Install
  anyway**. It may say this on updates too.
- **Obtainium's note about Google requiring developers to register
  (2026/2027).** This is about a future change to Android and changes nothing
  today. If a day comes when the phone refuses to install updates, the person
  who sent you this page will help you switch on a one-time setting for it.
- **"App not installed" or "conflicts with an existing package" on an
  update.** Don't uninstall anything (that would lose the app's data). Tell
  the person who sent you this page; it means something went wrong on their
  side.

Anything else odd: take a screenshot and send it to whoever sent you this page.
