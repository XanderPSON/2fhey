//
//  FillPopup.swift
//  2FHey
//
//  Fork: "Ask Before Filling". A small popup under the focused field with a Fill button,
//  like Safari's code suggestion. It never activates 2FHey, so the field keeps focus.
//

import Cocoa
import SwiftUI

enum FillPopup {
    static let gap: CGFloat = 6

    /// Window origin (Cocoa, bottom-left) for a popup of `size` under the field.
    /// `field` is an Accessibility frame (top-left origin of the primary screen, height `primaryHeight`).
    /// Flips above the field when there is no room below; stays inside `visible` horizontally.
    static func origin(field: CGRect, size: CGSize, primaryHeight: CGFloat, visible: CGRect) -> CGPoint {
        let fieldBottom = primaryHeight - field.maxY // Cocoa y of the field's bottom edge
        var y = fieldBottom - gap - size.height
        if y < visible.minY { y = primaryHeight - field.minY + gap }
        let x = min(max(field.minX, visible.minX), visible.maxX - size.width)
        return CGPoint(x: x, y: y)
    }
}

final class FillPanel: NSPanel {
    private final class HostingView<V: View>: NSHostingView<V> {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true } // one click fills, no focus click first
    }

    init(code: String, source: String?, near field: CGRect?, onFill: @escaping () -> Void, onClose: @escaping () -> Void) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let host = HostingView(rootView: FillView(code: code, source: source, onFill: onFill, onClose: onClose))
        let size = host.fittingSize
        contentView = host
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let primary = NSScreen.screens.first?.frame.height ?? 0
        let origin: CGPoint
        if let field, let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: field.midX, y: primary - field.midY)) }) {
            origin = FillPopup.origin(field: field, size: size, primaryHeight: primary, visible: screen.visibleFrame)
        } else { // no field frame: the notification corner
            let v = NSScreen.main?.visibleFrame ?? .zero
            let m = UIConstants.codePopupMargin
            switch AppStateManager.shared.notificationPosition {
            case .leftEdgeTop: origin = CGPoint(x: v.minX + m, y: v.maxY - m - size.height)
            case .leftEdgeBottom: origin = CGPoint(x: v.minX + m, y: v.minY + m)
            case .rightEdgeTop: origin = CGPoint(x: v.maxX - m - size.width, y: v.maxY - m - size.height)
            case .rightEdgeBottom: origin = CGPoint(x: v.maxX - m - size.width, y: v.minY + m)
            }
        }
        setFrame(NSRect(origin: origin, size: size), display: false)
        orderFrontRegardless()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct FillView: View {
    let code: String
    let source: String?
    let onFill: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.fill").foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(code).font(.system(size: 15, weight: .semibold, design: .monospaced))
                if let source { Text(source).font(.caption).foregroundColor(.secondary).lineLimit(1) }
            }
            Spacer(minLength: 8)
            Button("Fill", action: onFill)
            Button(action: onClose) { Image(systemName: "xmark").font(.caption.weight(.bold)) }
                .buttonStyle(.plain).foregroundColor(.secondary).help("Dismiss")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(minWidth: 220, maxWidth: 300)
        .background(VisualEffect().clipShape(RoundedRectangle(cornerRadius: 10)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.12)))
    }
}

private struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .popover
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
