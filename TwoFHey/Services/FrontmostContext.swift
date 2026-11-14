//
//  FrontmostContext.swift
//  2FHey
//
//  Fork: what the user is looking at (site host + page title for browsers, app
//  name otherwise) and whether a text field has focus.
//

import Cocoa
import ApplicationServices

struct FrontmostContext: Equatable {
    var host: String
    var title: String

    enum BrowserKind { case chromium, safari }

    static func browserKind(bundleID: String?) -> BrowserKind? {
        switch bundleID {
        case "com.google.Chrome", "com.google.Chrome.canary", "com.brave.Browser",
             "com.microsoft.edgemac", "company.thebrowser.Browser": return .chromium
        case "com.apple.Safari": return .safari
        default: return nil
        }
    }

    /// Script output is "<url>\n<title>".
    static func parse(scriptOutput: String) -> FrontmostContext? {
        let parts = scriptOutput.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        guard let urlPart = parts.first, let host = URL(string: String(urlPart))?.host else { return nil }
        return FrontmostContext(host: host, title: parts.count > 1 ? String(parts[1]) : "")
    }

    /// Main thread only (NSAppleScript). Falls back to the app name if the tab can't be read (e.g. Automation denied).
    static func current() -> FrontmostContext {
        guard let app = NSWorkspace.shared.frontmostApplication else { return FrontmostContext(host: "", title: "") }
        let fallback = FrontmostContext(host: "", title: app.localizedName ?? "")
        guard let kind = browserKind(bundleID: app.bundleIdentifier), let id = app.bundleIdentifier else { return fallback }
        let tab = kind == .safari ? "current tab" : "active tab"
        let source = "tell application id \"\(id)\" to return (URL of \(tab) of front window) & linefeed & (\(kind == .safari ? "name" : "title") of \(tab) of front window)"
        var error: NSDictionary?
        guard let out = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue, error == nil else { return fallback }
        return parse(scriptOutput: out) ?? fallback
    }

    /// nil when the check can't run (no permission / nothing reported).
    static func focusedElementIsTextInput() -> Bool? {
        guard let el = focusedElement() else { return nil }
        var role: AnyObject?
        guard AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &role) == .success else { return nil }
        return PasteGuard.isTextInputRole(role as? String)
    }

    /// Fork: the focused element's screen frame (Accessibility coordinates, top-left origin), for the Fill popup.
    static func focusedElementFrame() -> CGRect? {
        guard let el = focusedElement() else { return nil }
        var pos: AnyObject?, size: AnyObject?
        var point = CGPoint.zero, extent = CGSize.zero
        guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &pos) == .success,
              AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &size) == .success,
              AXValueGetValue(pos as! AXValue, .cgPoint, &point), AXValueGetValue(size as! AXValue, .cgSize, &extent),
              extent.width > 0 else { return nil }
        return CGRect(origin: point, size: extent)
    }

    private static func focusedElement() -> AXUIElement? {
        guard AXIsProcessTrusted() else { return nil }
        var focused: AnyObject?
        var err = AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused)
        if err != .success, let app = NSWorkspace.shared.frontmostApplication {
            // Chromium builds its accessibility tree on request; ask, then try the app element.
            let appEl = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetAttributeValue(appEl, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            err = AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &focused)
        }
        guard err == .success, let el = focused else { return nil }
        return (el as! AXUIElement)
    }
}
