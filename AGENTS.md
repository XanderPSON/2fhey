# 2FHey fork rules

- Swift/AppKit macOS app, fork of SoFriendly/2fhey (remote `upstream`). Commit to `main`, conventional commits.
- Mark every changed or added block `// Fork:`; keep changes small and in upstream's style; no refactors of upstream code beyond need. New code goes in `TwoFHey/Services/` (auto-included in the target).
- Every behaviour change ships with a unit test in `TwoFHeyTests` in the same commit. Put decision logic in small pure functions (see `PasteGuard`, `EmailCodeManager.newCodes`).
- Build/test commands and signing are in README "This fork". Never replace /Applications/2FHey.app from an agent session.
- The email source depends on the local helper at `~/Developer/chrome-extensions/email-code-fill/helper` (port 3078); do not talk to Gmail directly.
