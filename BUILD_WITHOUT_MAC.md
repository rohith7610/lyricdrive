# Build LyricDrive Without Owning a Mac

You can develop the source code on Windows. To **compile and install** on your iPhone, iOS tooling must run on macOS. These are practical options for **personal use only**.

---

## Option A — GitHub Actions (recommended, free tier)

GitHub provides free macOS runners. Use them to verify builds and optionally produce an IPA.

### Step 1: Push this repo to GitHub

```powershell
cd d:\PROJECTS\car
git init
git add .
git commit -m "LyricDrive personal build"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/lyricdrive.git
git push -u origin main
```

### Step 2: Automatic compile + tests

Every push runs `.github/workflows/ios-build.yml`:
- Generates the Xcode project with XcodeGen
- Builds for iOS Simulator
- Runs unit tests

Check **Actions** tab on GitHub for green/red status.

### Step 3: Build an IPA for your iPhone (manual trigger)

1. Create a **free Apple ID** at [appleid.apple.com](https://appleid.apple.com)
2. Enable two-factor authentication
3. Create an **app-specific password**: Apple ID → Sign-In and Security → App-Specific Passwords
4. Find your **Team ID** at [developer.apple.com/account](https://developer.apple.com/account) (Membership details)

Add GitHub repository secrets (`Settings → Secrets → Actions`):

| Secret | Value |
|--------|-------|
| `APPLE_ID` | Your Apple ID email |
| `APPLE_APP_SPECIFIC_PASSWORD` | Generated password |
| `TEAM_ID` | 10-character team ID |

5. Go to **Actions → LyricDrive CI → Run workflow**
6. When finished, download the **LyricDrive-ipa** artifact

### Step 4: Install on iPhone from Windows

Use one of these tools on your PC:

- **[Sideloadly](https://sideloadly.io/)** — drag IPA, enter Apple ID, install over USB/Wi‑Fi
- **[AltStore](https://altstore.io/)** — requires AltServer on a PC + same Wi‑Fi network

**Note:** Free Apple accounts require re-signing every **7 days**.

---

## Option B — Borrow / rent a Mac (one-time setup)

Rent MacinCloud, AWS EC2 Mac, or use a friend's Mac for 1–2 hours:

```bash
brew install xcodegen
cd lyricdrive
xcodegen generate
open LyricDrive.xcodeproj
```

1. Connect iPhone via USB
2. Select your device in Xcode
3. Sign in with your Apple ID (Xcode → Settings → Accounts)
4. Press **Run** (▶)

This is the simplest path if you can access a Mac once.

---

## Option C — Cloud Mac IDE

Services like **GitHub Codespaces does NOT support Xcode**. You still need a real macOS environment (Option A or B).

---

## Signing notes for personal use

| Topic | Detail |
|-------|--------|
| Default entitlements | App Groups only — works with free provisioning |
| CarPlay | Optional — swap to `LyricDrive.carplay.entitlements` only if Apple grants CarPlay entitlement |
| Bundle ID | Change `com.lyricdrive.app` in `project.yml` to something unique, e.g. `com.yourname.lyricdrive` |
| Widget | Must use same App Group in main app + widget entitlements |

---

## After install — first-run checklist

1. Open **LyricDrive** while music plays in Spotify / Apple Music / YouTube Music
2. Grant **microphone** only when using Shazam (Settings → Detection → Auto Shazam Fallback)
3. Enable **Driving** font size in Settings → Display
4. Add lock screen widget: long-press Lock Screen → Customize → add LyricDrive widget
5. For Spotify controls: use Spotify's lock screen controls (in-app buttons target Apple Music only)

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| No song detected | Open LyricDrive while music plays; ensure Control Center shows the track |
| Lyrics out of sync | Some apps update position slowly — wait one line, or use Apple Music |
| Shazam fails | Reduce background noise; play music louder; try manual Search |
| Widget shows placeholder | Open app once while music plays (shared App Group data) |
| Install expires in 7 days | Re-run Sideloadly or GitHub IPA workflow |
| GitHub Actions exit code 70 | Fixed in latest workflow — push again; was invalid `OS=latest` simulator |

---

## What you cannot do on Windows alone

- Run Xcode locally
- Debug on a connected iPhone directly from Windows
- Submit to App Store (not needed for personal use)

Everything else — source code, fixes, GitHub builds — can be managed from your PC.
