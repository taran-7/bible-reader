import AppKit
import BibleCore
import SwiftUI

/// Esc and a click outside the verse text (the window header, the book list, the history panel) deselect the verses (FR-17).
/// The Edit → Deselect menu item stays for discoverability, but a menu shortcut depends on the focus and on SwiftUI
/// refreshing the menu in time, so the key and the click are also caught here, whatever has the focus.
/// An Esc nobody uses is swallowed in full screen, where AppKit would leave the mode on it.
/// What may deselect is decided by `ReaderViewModel`; this only reads the window.
struct SelectionDismissal: NSViewRepresentable {
    let model: ReaderViewModel
    let drafts: DraftStore
    let readingArea: ReadingAreaTracker

    func makeCoordinator() -> Monitor { Monitor() }

    func makeNSView(context: Context) -> NSView {
        let view = WindowObserver()
        view.onWindow = { [coordinator = context.coordinator] window in coordinator.attach(to: window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.model = model
        context.coordinator.drafts = drafts
        context.coordinator.readingArea = readingArea
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
        var readingArea: ReadingAreaTracker?
        private weak var window: NSWindow?
        private var tokens: [Any] = []

        func attach(to window: NSWindow?) {
            detach()
            guard let window else { return }
            self.window = window
            // Not `self?.keyDown(event) ?? event`: the handler's `nil` (swallow the event) would turn back into the event.
            let key = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.keyDown(event)
            }
            let click = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                guard let self else { return event }
                return self.mouseDown(event)
            }
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
            if model.escapeClearsSelection(otherOwnsEscape: otherOwnsEscape) {
                model.clearSelection()
                return nil
            }
            return window.styleMask.contains(.fullScreen) && model.escapeIsFree(otherOwnsEscape: otherOwnsEscape) ? nil : event
        }

        /// The click goes on: a drag of the title bar, a double-click to zoom the window and the control under it keep working.
        private func mouseDown(_ event: NSEvent) -> NSEvent? {
            guard let window, event.window === window, let model, let drafts else { return event }
            let point = event.locationInWindow
            let clears: Bool
            if point.y > window.contentLayoutRect.maxY {
                clears = model.headerClickClearsSelection() && Self.isEmptyHeader(at: point, in: window)
            } else {
                // Inside the verse list a click selects verses; elsewhere it deselects, unless it lands on a control.
                clears = model.outsideClickClearsSelection(draftsOpen: drafts.isOpen || drafts.isPresenting)
                    && readingArea?.contains(point) != true && Self.isPlainContent(at: point, in: window)
            }
            if clears { model.clearSelection() }
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
            return !isControl(at: point, in: window)
        }

        /// A point in the content that is not a divider of the split view, a control or a text view.
        static func isPlainContent(at point: NSPoint, in window: NSWindow) -> Bool {
            !(window.contentView?.superview?.hitTest(point) is NSSplitView) && !isControl(at: point, in: window)
        }

        private static func isControl(at point: NSPoint, in window: NSWindow) -> Bool {
            var view = window.contentView?.superview?.hitTest(point)
            while let current = view {
                if current is NSControl || current is NSText { return true }
                view = current.superview
            }
            return false
        }
    }
}

/// The frame of the verse list, reported by `ChapterView`: a click inside it selects verses and never counts as "outside".
@MainActor final class ReadingAreaTracker {
    fileprivate(set) weak var view: NSView?

    func contains(_ pointInWindow: NSPoint) -> Bool {
        guard let view, view.window != nil else { return false }
        return view.convert(view.bounds, to: nil).contains(pointInWindow)
    }
}

/// A background of the verse list that fills exactly its frame.
struct ReadingAreaMarker: NSViewRepresentable {
    let tracker: ReadingAreaTracker

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        tracker.view = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) { tracker.view = view }
}
