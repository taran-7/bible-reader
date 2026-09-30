# Frontend (SwiftUI)

- Window: `NavigationSplitView`. Sidebar: 66 books (OT/NT) in the active translation's language. Main area: chapter text with verse numbers.
- Toolbar: KJV / Synodal switcher, ◀ ▶, chapter picker, `.searchable`.
- Search: a reference jumps to the passage; otherwise a result list with the match highlighted.
- Copying: ⌘C and a context menu on selected verses.
- Views never touch the database directly, only through `ReaderViewModel`.
