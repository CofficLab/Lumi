import SwiftUI

/// Semantic names for the SF Symbols the shared component library uses most.
///
/// A raw `"play.fill"` string literal is easy to typo and impossible to search
/// for later. These constants give every symbol one declaration, so renaming a
/// glyph in one place updates all call sites across every consumer.
///
/// ```swift
/// Image(systemName: AppSymbol.playFill)
/// Image.appPlayFill
/// ```
public enum AppSymbol {
    // MARK: - Media

    /// Filled play glyph.
    public static let playFill = "play.fill"
    /// Filled pause glyph.
    public static let pauseFill = "pause.fill"
    /// Jump backward.
    public static let backward = "backward"
    /// Jump forward.
    public static let forward = "forward"
    /// Previous item, drawn as a chevron.
    public static let previousPage = "chevron.backward"
    /// Next item, drawn as a chevron.
    public static let nextPage = "chevron.forward"
    /// Repeat a single item.
    public static let repeatOne = "repeat.1"
    /// Repeat the whole queue.
    public static let repeatAll = "repeat"
    /// Shuffle the queue.
    public static let shuffle = "shuffle"

    // MARK: - Library

    /// Musical note, used for audio artwork placeholders.
    public static let musicNote = "music.note"
    /// Musical note inside a house, used for a library tab.
    public static let musicLibrary = "music.note.house"
    /// Musical note beside a list.
    public static let musicNoteList = "music.note.list"

    // MARK: - Files

    /// Folder.
    public static let folder = "folder"
    /// Generic text document.
    public static let document = "doc.text"
    /// Photo stack.
    public static let photos = "photo.on.rectangle.fill"
    /// Window outline used for desktop surfaces.
    public static let finderWindow = "macwindow"
    /// Circle with an arrow, used for reveal-in-file-browser actions.
    public static let showInFinder = "arrow.forward.circle"
    /// Circle with an up arrow.
    public static let arrowUpCircle = "arrow.up.circle"
    /// Counterclockwise arrow, used for reset and refresh actions.
    public static let reset = "arrow.counterclockwise"

    // MARK: - Actions & status

    /// Bare checkmark.
    public static let checkmark = "checkmark"
    /// Filled circle with an x, used for dismiss buttons.
    public static let close = "xmark.circle.fill"
    /// Filled circle with an i, used for informational affordances.
    public static let info = "info.circle"
    /// Bulleted list.
    public static let list = "list.bullet"
    /// Horizontal ellipsis, used for overflow menus.
    public static let more = "ellipsis"
    /// Heart, used for favorite and like toggles.
    public static let heart = "heart"
    /// Cloud, used for sync state.
    public static let cloud = "cloud"
    /// App Store storefront.
    public static let appStore = "storefront"
}

public extension Image {
    // MARK: - Media

    /// Filled play glyph.
    static var appPlayFill: Image { Image(systemName: AppSymbol.playFill) }
    /// Filled pause glyph.
    static var appPauseFill: Image { Image(systemName: AppSymbol.pauseFill) }
    /// Jump backward.
    static var appBackward: Image { Image(systemName: AppSymbol.backward) }
    /// Jump forward.
    static var appForward: Image { Image(systemName: AppSymbol.forward) }
    /// Previous item, drawn as a chevron.
    static var appPreviousPage: Image { Image(systemName: AppSymbol.previousPage) }
    /// Next item, drawn as a chevron.
    static var appNextPage: Image { Image(systemName: AppSymbol.nextPage) }

    // MARK: - Library

    /// Musical note, used for audio artwork placeholders.
    static var appMusicNote: Image { Image(systemName: AppSymbol.musicNote) }
    /// Musical note inside a house, used for a library tab.
    static var appMusicLibrary: Image { Image(systemName: AppSymbol.musicLibrary) }

    // MARK: - Actions & status

    /// Filled circle with an x, used for dismiss buttons.
    static var appClose: Image { Image(systemName: AppSymbol.close) }
    /// Filled circle with an i, used for informational affordances.
    static var appInfo: Image { Image(systemName: AppSymbol.info) }
    /// Bulleted list.
    static var appList: Image { Image(systemName: AppSymbol.list) }
    /// Horizontal ellipsis, used for overflow menus.
    static var appMore: Image { Image(systemName: AppSymbol.more) }
    /// Heart, used for favorite and like toggles.
    static var appHeart: Image { Image(systemName: AppSymbol.heart) }
    /// Counterclockwise arrow, used for reset and refresh actions.
    static var appReset: Image { Image(systemName: AppSymbol.reset) }
    /// Cloud, used for sync state.
    static var appCloud: Image { Image(systemName: AppSymbol.cloud) }
    /// App Store storefront.
    static var appAppStore: Image { Image(systemName: AppSymbol.appStore) }
}
