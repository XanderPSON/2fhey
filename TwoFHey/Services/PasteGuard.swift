//
//  PasteGuard.swift
//  2FHey
//
//  Fork: pure decision logic for "should this code be auto-pasted here?", plus
//  the small string helpers it uses. No UI or system calls, so it is unit tested.
//

import Foundation

// Fork: where the code came from, with whatever the source knows about it.
enum CodeOrigin: Equatable {
    case email(match: Bool, onlyFresh: Bool)
    case message(service: String?)
}

struct PasteDecision: Equatable {
    let paste: Bool
    /// Why the paste was skipped, ready to show after "Copied — ".
    let reason: String?
}

enum PasteGuard {
    /// Lowercase letters and digits only.
    static func normalize(_ s: String) -> String {
        String(s.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    /// The registrable label of a host: `www.cgtrader.com` -> `cgtrader`, `shop.example.co.uk` -> `example`.
    static func siteName(fromHost host: String) -> String {
        let labels = host.lowercased().split(separator: ".").map(String.init)
        guard labels.count >= 2 else { return labels.first ?? "" }
        let secondLevel: Set<String> = ["co", "com", "org", "net", "ac", "gov", "edu"]
        if labels.count >= 3, labels[labels.count - 1].count == 2, secondLevel.contains(labels[labels.count - 2]) {
            return labels[labels.count - 3]
        }
        return labels[labels.count - 2]
    }

    /// True unless we know the service and it clearly differs from the current site/app.
    static func serviceMatches(_ service: String?, host: String, title: String) -> Bool {
        let s = normalize(service ?? "")
        let site = normalize(siteName(fromHost: host))
        let t = normalize(title)
        if s.isEmpty || (site.isEmpty && t.isEmpty) { return true }
        if !site.isEmpty && (s.contains(site) || site.contains(s)) { return true }
        if !t.isEmpty && (t.contains(s) || s.contains(t)) { return true }
        return false
    }

    /// `focusedIsTextInput` is nil when the Accessibility check could not run (keep upstream behaviour).
    static func decide(origin: CodeOrigin, host: String, title: String, focusedIsTextInput: Bool?) -> PasteDecision {
        let target = host.isEmpty ? title : host
        switch origin {
        case let .email(match, onlyFresh):
            // A sole unmatched code is fine only when we have no site to contradict it.
            if !(match || (onlyFresh && host.isEmpty)) { return PasteDecision(paste: false, reason: "didn't match \(target)") }
        case let .message(service):
            if !serviceMatches(service, host: host, title: title) { return PasteDecision(paste: false, reason: "didn't match \(target)") }
        }
        if focusedIsTextInput == false { return PasteDecision(paste: false, reason: "no text field focused") }
        return PasteDecision(paste: true, reason: nil)
    }

    static func isTextInputRole(_ role: String?) -> Bool {
        ["AXTextField", "AXTextArea", "AXComboBox"].contains(role ?? "")
    }

    /// Recent-menu title: where the code came from.
    static func recentTitle(code: String, service: String?, isEmail: Bool) -> String {
        let who = service ?? "Unknown"
        return "\(code) - \(isEmail ? "✉ \(who)" : "💬 \(who)")"
    }
}
