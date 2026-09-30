import Foundation

/// The copy button on the selection (FR-17): where it stands and how long "Copied" lasts.
public enum CopyButtonModel {
    public static let feedbackDuration: Duration = .milliseconds(1500)

    /// The verse the button stands above: the first selected one; no selection, no button.
    public static func anchorVerse(for selection: Set<Int>) -> Int? { selection.min() }
}
