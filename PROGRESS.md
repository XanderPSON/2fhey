# Progress

- 2026-11-13: forked; added EmailCodeManager, merged sources, PasteGuard/FrontmostContext site+focus check, origin icons in Recent menu, tests (31 pass), signed with team 9876F9A9FU.
- 2026-11-13: Installed the fork in /Applications (upstream 2.0 moved to Trash). Skipped email codes now stay unused for the Chrome extension.
- 2026-11-14: Ask Before Filling: Fill popup under the focused field instead of auto-pasting (default on).
- 2026-11-14: Separate on/off switches for iMessage (message) codes and email codes.
- 2026-11-15: Setup window no longer pops at login on a transient permission miss (10s re-check); FDA probe reads 16 bytes, not all of chat.db (RSS 650MB → 73MB).
- 2026-11-26: Filled text codes now get marked read in Messages.app (row "Mark as Read" AX action, Messages stays in the background); upstream's chat.db write never reached the UI or iPhone. Skipped codes stay unread. 39 tests pass; installed.
