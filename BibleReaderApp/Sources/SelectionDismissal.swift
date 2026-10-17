import AppKit
import BibleCore
import SwiftUI

/// Esc and a click on the window header (title bar, empty toolbar space) deselect the verses (FR-17).
/// The Edit → Deselect menu item stays for discoverability, but a menu shortcut depends on the focus and on SwiftUI
/// refreshing the menu in time, so the key and the click are also caught here, whatever has the focus.
/// What may deselect is decided by `ReaderViewModel`; this only reads the window.
struct SelectionDismissal: NSViewRepresentable {
    let model: ReaderViewModel
    let drafts: DraftStore

    func makeCoordinator() -> Monitor { Monitor() }

    func makeNSView(context: Context) -> NSView {
        let view = WindowObserver()
        view.onWindow = { [coordinator = context.coordinator] window in coordinator.attach(to: window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.model = model
        context.coordinator.drafts = drafts
    }

    static func dismantleNSView(_ view: NSView, coordinator: Monitor) { coordinator.detach() }

    /// Reports the window the view lands in; the monitors only act on events of that window.
    final class WindowObserver: NSView {
        var onWindow: (NSWindow?) -> Void = { _ in }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindow(window)
        }
    }

    @MainActor final class Monitor {
        var model: ReaderViewModel?
        var drafts: DraftStore?
        private weak var window: NSWindow?
        private var tokens: [Any] = []

        func attach(to window: NSWindow?) {
            detach()
            guard let window else { return }
            self.window = window
            let key = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in self?.keyDown(event) ?? event }
            let click = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in self?.mouseDown(event) ?? event }
            tokens = [key, click].compactMap { $0 }
        }

        func detach() {
            tokens.forEach(NSEvent.removeMonitor)
            tokens = []
            window = nil
        }

        private func keyDown(_ event: NSEvent) -> NSEvent? {
            guard event.keyCode == Self.escapeKeyCode, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
                  let window, event.window === window, let model, let drafts else { return event }
            // A text field being edited (the search field, a note) has the field editor as first responder and owns Esc;
            // a sheet and the drafts panel own it too. The popover of the chapter picker is a window of its own.
            let otherOwnsEscape = window.firstResponder is NSText || window.attachedSheet != nil || drafts.isOpen || drafts.isPresenting
            guard model.escapeClearsSelection(otherOwnsEscape: otherOwnsEscape) else { return event }
            model.clearSelection()
            return nil
        }

        /// The click goes on: a drag of the title bar and a double-click to zoom the window keep working.
        private func mouseDown(_ event: NSEvent) -> NSEvent? {
            guard let window, event.window === window, let model, model.headerClickClearsSelection(),
                  Self.isEmptyHeader(at: event.locationInWindow, in: window) else { return event }
            model.clearSelection()
            return event
        }

        private static let escapeKeyCode: UInt16 = 53
        /// Toolbar items sit in rounded capsules a few points wider than their views.
        private static let controlMargin: CGFloat = 8

        /// The point is in the band above the content (title bar and toolbar) and over no control: not the window buttons,
        /// not a toolbar item, not anything that is a control or a text view.
        static func isEmptyHeader(at point: NSPoint, in window: NSWindow) -> Bool {
            guard point.y > window.contentLayoutRect.maxY else { return false }
            let buttons = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].compactMap(window.standardWindowButton)
            let itemViews = (window.toolbar?.items ?? []).compactMap(\.view)
            let occupied = (buttons + itemViews).map {
                $0.convert($0.bounds, to: nil).insetBy(dx: -controlMargin, dy: -controlMargin)
            }
            guard !occupied.contains(where: { $0.contains(point) }) else { return false }
            var view = window.contentView?.superview?.hitTest(point)
            while let current = view {
                if current is NSControl || current is NSText { return false }
                view = current.superview
            }
            return true
        }
    }
}
