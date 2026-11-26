//
//  MessagesReadMarker.swift
//  2FHey
//
//  Fork: marks a code text read in Messages.app through the conversation row's own
//  "Mark as Read" accessibility action, with Messages left in the background.
//  Upstream wrote is_read straight into chat.db, which Messages and the iPhone never saw.
//

import Cocoa
import ApplicationServices

enum MessagesReadMarker {
    /// Messages labels a row "<name>, [Unread, ]<preview>, <time>"; previews are cut at ~200 characters.
    static func rowMatches(label: String, messageText: String) -> Bool {
        let preview = squash(String(messageText.prefix(100)))
        return !preview.isEmpty && squash(label).contains(preview)
    }

    private static func squash(_ s: String) -> String { s.split(whereSeparator: \.isWhitespace).joined(separator: " ") }

    /// Retries for a few seconds: right after a text arrives Messages may not have listed it yet.
    // shortcut: English action name, and only rows Messages has loaded (new texts sit at the top); needs a Messages window open.
    static func markRead(messageText: String, attempt: Int = 0) {
        guard AXIsProcessTrusted(),
              let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MobileSMS").first?.processIdentifier
        else { return }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 1)
        let rows = (children(app, "AXWindows") ?? []).compactMap(conversationList).flatMap { children($0, "AXChildren") ?? [] }
        if let row = rows.first(where: { rowMatches(label: string($0, "AXDescription") ?? "", messageText: messageText) }) {
            var names: CFArray?
            AXUIElementCopyActionNames(row, &names)
            if let action = (names as? [String])?.first(where: { $0.hasPrefix("Name:Mark as Read\n") }) {
                AXUIElementPerformAction(row, action as CFString)
            }
            return // no "Mark as Read" means it is already read
        }
        guard attempt < 5 else { return }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) { markRead(messageText: messageText, attempt: attempt + 1) }
    }

    private static func conversationList(_ e: AXUIElement) -> AXUIElement? {
        if string(e, "AXIdentifier") == "ConversationList" { return e }
        return (children(e, "AXChildren") ?? []).lazy.compactMap(conversationList).first
    }

    private static func children(_ e: AXUIElement, _ attr: String) -> [AXUIElement]? {
        var v: AnyObject?
        AXUIElementCopyAttributeValue(e, attr as CFString, &v)
        return v as? [AXUIElement]
    }

    private static func string(_ e: AXUIElement, _ attr: String) -> String? {
        var v: AnyObject?
        AXUIElementCopyAttributeValue(e, attr as CFString, &v)
        return v as? String
    }
}
