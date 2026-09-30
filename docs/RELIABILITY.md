# Reliability

- The database is opened read-only from the bundle; if it fails to open, an error screen is shown.
- The FTS query is escaped, so malformed input (`"`, `*`) does not crash the app.
- Empty search result: "Nothing found".
