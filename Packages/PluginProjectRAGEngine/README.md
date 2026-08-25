# ProjectRAGPlugin

Retrieval-Augmented Generation

## Optional sqlite-vec extension

`vec0.dylib` accelerates vector search but is deliberately not committed to the
repository. A build without it uses the built-in Swift cosine-similarity
backend. To enable the extension locally, place a compatible signed library at
`Resources/vec0.dylib`; Xcode embeds and signs it when present.
