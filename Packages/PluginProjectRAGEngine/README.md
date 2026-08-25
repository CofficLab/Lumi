# ProjectRAGPlugin

Retrieval-Augmented Generation

## Required sqlite-vec extension

RAG always uses the sqlite-vec ANN backend. The universal `Resources/vec0.dylib`
is tracked in this repository, copied into the Swift package resource bundle,
and embedded and signed by the Xcode build phase. If the extension is missing,
incompatible, or cannot be loaded, RAG fails explicitly; it never falls back to
the built-in Swift vector search.
