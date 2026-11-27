# 2FHey (Xander's fork)

## This fork

Fork of [SoFriendly/2fhey](https://github.com/SoFriendly/2fhey) (CC0) that adds emailed verification codes and a "is this the right place?" check before auto-paste.

**What changed** (every block is marked `// Fork:`; new files live in `TwoFHey/Services/`):
- `EmailCodeManager`: polls the local Gmail helper (`infra`-side `chrome-extensions/email-code-fill/helper`, `127.0.0.1:3078`) every 5 s (30 s while it is down), emits fresh codes (age <= 120 s) once, and marks them used via `POST /used` so the Chrome extension chip also disappears. Runs alongside the iMessage / Google Messages source; "Email Codes" toggle in Settings (default on).
- `PasteGuard` (pure, tested): auto-paste only when the code belongs to the frontmost site/app (email `match`, or a sole unmatched code with no site to contradict it; message `service` vs host/title) and a text field/area/combo box has focus. When skipped, the code is still copied and the notification says why ("Copied — didn't match chatgpt.com").
- **iMessage Codes / Email Codes** (Settings): turn each source on or off on its own; both on by default. With message codes off, 2FHey stops reading Messages and skips the Full Disk Access prompt.
- **Ask Before Filling** (Settings, on by default): instead of pasting, a code that passes the site check shows a small popup under the focused field with a **Fill** button (`FillPopup.swift`, a non-activating panel so the field keeps focus). Clicking Fill pastes it and marks an email code used; the popup closes after 30 s. Turn it off to paste straight away.
- **Mark Messages as Read** (`MessagesReadMarker`): once 2FHey fills a texted code (auto-paste, or clicking Fill), it marks that conversation read in Messages.app through the row's own "Mark as Read" accessibility action, with Messages left in the background, so it clears on the iPhone too. Skipped codes stay unread. Upstream wrote `is_read` into chat.db, which Messages never noticed. Needs a Messages window open (it can be behind other windows).
- **Apple AutoFill first** (iMessage codes): if Apple's own "from Messages" AutoFill popup is on screen (a window of `com.apple.SafariPlatformSupport.Helper`, shown in Chrome too), 2FHey shows no popup, paste or notification of its own. It waits up to 2.5 s for Apple's popup before offering its own.
- **Mark done however it was filled**: for 2 minutes after a code arrives, 2FHey checks whether the focused field holds the code (from Apple's AutoFill, typed or pasted). If it does, the text is marked read in Messages, or the email is marked read and archived (helper `POST /used`). A code split across one-digit boxes isn't seen.
- `FrontmostContext`: frontmost app, plus URL host and title for Chrome/Canary/Brave/Edge/Arc/Safari via AppleScript (falls back to the app name if Automation is denied); AX focused-element role check.
- Recent menu shows the origin (✉ sender / 💬 service). Entitlement `automation.apple-events` + `NSAppleEventsUsageDescription` added.

**Build / install** (signed with Xander's Apple Development team 9876F9A9FU; upstream's team is not ours):
```
xcodebuild build -scheme TwoFHey -configuration Release -destination 'platform=macOS' -derivedDataPath build \
  DEVELOPMENT_TEAM=9876F9A9FU MACOSX_DEPLOYMENT_TARGET=12.4 -allowProvisioningUpdates
# app: build/Build/Products/Release/2FHey.app   (copy to /Applications yourself)
xcodebuild test -scheme TwoFHey -destination 'platform=macOS' -derivedDataPath build DEVELOPMENT_TEAM=9876F9A9FU MACOSX_DEPLOYMENT_TARGET=12.4
```
`MACOSX_DEPLOYMENT_TARGET=12.4` is needed because upstream's AutoLauncher target says 10.15, which current Xcode rejects. Permissions: Full Disk Access, Accessibility, and Automation (per browser, asked on first use). Same bundle ID as upstream, so remove the old copy before running this one.

**Merge upstream:** `git fetch upstream && git merge upstream/main`. Conflicts should only be in `AppDelegate.swift` (Fork-marked blocks).

See `PROGRESS.md` and `AGENTS.md`.

---

# 2FHey

Automatically detect and copy verification codes from iMessage and SMS.

[![Fund contributors](https://img.shields.io/badge/%F0%9F%91%91_Fund_contributors-royalty.dev-BB953A?style=for-the-badge&labelColor=1a1a1a)](https://app.royalty.dev/SoFriendly/2fhey)

## Features

- 🔐 Automatic OTP detection from messages
- 📋 Auto-copy to clipboard
- ⌨️ Optional auto-paste
- 🔔 Desktop notifications
- 🎯 Global keyboard shortcut (⇧⌘E) to resync messages
- 🌐 Support for 145+ services

## How It Works

2FHey uses smart keyword-based detection to identify verification code messages. When a message contains words like "verification", "code", "OTP", "PIN", etc., it automatically:

1. Extracts 4-8 digit codes (or alphanumeric codes)
2. Identifies the service (Google, Apple, Bank, etc.)
3. Copies the code to your clipboard
4. Shows a notification overlay
5. Optionally auto-pastes the code

## Supported Formats

The app automatically detects codes in various formats:
- Standard digits: `123456`
- Spaced/dashed: `123-456` or `123 456`
- Alphanumeric: `ABC123`, `X7Y9Z2`
- Google format: `G-12345`
- Chinese brackets: `【验证码123456】`

## Installation

1. Download from [2fhey.com](https://2fhey.com) (via Gumroad)
2. Move to Applications folder
3. Launch and grant required permissions:
   - **Full Disk Access** - to read Messages database
   - **Accessibility** - for auto-paste and keyboard shortcuts

## Keyboard Shortcuts

- **⇧⌘E** (Shift + Command + E) - Resync messages and copy the latest OTP code to clipboard
  - Useful if 2FHey missed a message or you need to retrieve a recent code again
  - Can be disabled in Settings if it conflicts with other apps

## Custom Services

If you use a service that isn't automatically recognized, you can add it to the known services list by creating a PR to update `OTPParserConstants.knownServices` in `TwoFHey/OTPParser/OTPParserContants.swift`.

## Multi-Language Support

2FHey supports OTP detection in multiple languages including English, French, Spanish, Portuguese, German, and Chinese. The language files are automatically updated from GitHub without requiring a new app release.

### How It Works

The app uses a three-tier loading strategy:

1. **First launch:** Loads from bundled language files and custom patterns (immediate availability)
2. **Subsequent launches:** Loads from cached files (fast)
3. **Background update:** Fetches latest from GitHub on each app launch

Files are fetched from:
```
https://raw.githubusercontent.com/SoFriendly/2fhey/main/TwoFHey/OTPKeywords/{language}.json
https://raw.githubusercontent.com/SoFriendly/2fhey/main/TwoFHey/OTPKeywords/custom-patterns.json
```

### Adding a New Language

To add support for a new language:

1. Create a new JSON file in `TwoFHey/OTPKeywords/` with the following structure:
   ```json
   {
     "keywords": [
       "code",
       "verification",
       "verify"
     ],
     "patterns": [
       "code[\\s:]+([\\d\\s-]{4,8})",
       "verification[\\s:]+([\\d\\s-]{4,8})"
     ]
   }
   ```

2. Add the filename to the `languageFiles` array in `SimpleOTPParser.swift:22`

3. Submit a pull request

4. All users will receive the new language support on their next app launch (no binary update required!)

### Adding Custom Service Patterns

For services with unique OTP formats (like Chase, Geico, etc.), you can add patterns to `TwoFHey/OTPKeywords/custom-patterns.json`:

```json
{
  "customPatterns": [
    {
      "service": "YourService",
      "pattern": "YourService code: (\\d{6})"
    }
  ]
}
```

**Pattern tips:**
- Use capture groups `()` to extract the code
- First capture group will be used as the OTP code
- Service name is automatically associated with the pattern
- Patterns are checked first (highest priority)

Custom patterns are also updated remotely from GitHub on app launch.

### Language File Format

Each language file contains:

- **keywords**: An array of words that indicate an OTP message (e.g., "code", "verification", "vérification")
  - All keywords from all languages are merged and checked together
  - This allows detection of multilingual messages

- **patterns**: An array of regex patterns for language-specific code extraction
  - These are high-priority patterns like `"验证码：123456"` or `"code: 123456"`
  - Pattern captures should extract just the numeric code in capture group 1
  - Patterns are checked before generic digit extraction

### Cache Location

Downloaded language files and custom patterns are cached at: `~/Library/Caches/OTPKeywords/`

### Offline Support

If GitHub is unreachable, the app automatically falls back to:
1. Cached files from previous downloads
2. Bundled files included in the app

## Development Notes

**Version 2.0+** uses a simplified keyword-based OTP parser (`SimpleOTPParser.swift`) instead of complex regex patterns. This makes the app more reliable and easier to maintain.

The old regex-based system (`AppConfig.json` and 130+ service patterns) has been deprecated in favor of smart detection that works with any service.
