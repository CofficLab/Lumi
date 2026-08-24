import Foundation
import KernelLumi

/// Notifications broadcast by Agent tools when they mutate story/chapter data,
/// so the rail tab (and any other observer) can refresh itself.
extension Notification.Name {
    /// Posted after any tool writes to the story store (create/update/delete or
    /// import/export). Listeners should reload the full data set.
    static let storyWriterDidChange = Notification.Name("com.coffic.lumi.plugin.story-writer.didChange")
}

/// Helper that resolves the on-disk plugin directory for story data, so tools
/// and the view model agree on where to read/write.
enum StoryWriterStorage {
    static let pluginID = "StoryWriter"
    @MainActor static var v2Directory: URL?

    /// Returns the on-disk directory for the story store, or nil if the
    /// kernel's storage service is not available.
    static func directory(kernel: KernelLumi) async -> URL? {
        await MainActor.run {
            kernel.storage?.pluginDataDirectory(for: pluginID)
        }
    }

    @MainActor static func configureV2(directory: URL?) {
        v2Directory = directory
    }
}
