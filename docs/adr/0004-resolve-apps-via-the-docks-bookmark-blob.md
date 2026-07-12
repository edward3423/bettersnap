# Resolve Pinned Apps via the Dock's own bookmark blob

Each entry in `persistent-apps` carries a `tile-data.book` key - several hundred bytes of CFURL **bookmark data**, the same mechanism behind Finder aliases. It encodes the app's inode, volume, path and bundle identifier, and resolution tries them in turn. The `file-data._CFURLString` path sitting next to it is only a cached hint.

This means the Dock does not resolve a tile by its path, which is why moving or renaming an app does not break its Dock icon. BetterSnap resolves the same `book` blob, via `URL(resolvingBookmarkData:options:relativeTo:bookmarkDataIsStale:)` with `.withoutUI` and `.withoutMounting` so it can never block on a missing volume, and falls back to the path and then the bundle identifier if resolution fails.

We do this rather than re-implementing "path, then look up the bundle ID" ourselves because the app's whole premise is that **Slot N is the Nth icon in your Dock**. Resolving the way the Dock resolves makes that true by construction: BetterSnap finds an app if and only if the Dock finds it. Any hand-rolled approximation is a second implementation of Apple's resolution logic that will drift from the real one in ways we would have to discover one bug at a time.

The immediate motivation was concrete: one of the pinned apps on this machine lives in a project's `dist/` build directory, and another (Safari) lives under `/System/Volumes/Preboot/Cryptexes/App/`, a path that has moved across OS releases.

## Consequences

Resolution is not free - a bookmark resolve can touch the disk. It happens only when the Slot Map is rebuilt, at launch and on a Dock change, and never while handling a keypress.

If the blob resolves but reports `bookmarkDataIsStale`, we still use the result. We never write a refreshed bookmark back: `com.apple.dock.plist` belongs to the Dock, and BetterSnap only ever reads it.
