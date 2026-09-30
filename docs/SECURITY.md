# Security

- The app is offline: no network requests and no data collection.
- The KJV and Synodal texts are in the public domain; the source is recorded in `data/raw/SOURCE.md`.
- The database is read-only; user input reaches SQL only through GRDB parameters.
