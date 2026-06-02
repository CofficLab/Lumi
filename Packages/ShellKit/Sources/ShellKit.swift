// ShellKit - Modern async Process execution library
//
// Provides safe, non-blocking shell command execution with:
// - Async/await support
// - Streaming output callbacks
// - Timeout and cancellation support
// - Background queue execution (never blocks MainActor)

@_exported import Foundation

// Public API exports
public typealias Shell = ShellExecutor  // Convenience alias