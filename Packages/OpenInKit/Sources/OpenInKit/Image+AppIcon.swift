import SwiftUI

public extension Image {
    static var xcodeApp: Image { appIcon(for: .xcode) }
    static var vscodeApp: Image { appIcon(for: .vscode) }
    static var cursorApp: Image { appIcon(for: .cursor) }
    static var traeApp: Image { appIcon(for: .trae) }
    static var antigravityApp: Image { appIcon(for: .antigravity) }
    static var githubDesktopApp: Image { appIcon(for: .githubDesktop) }
    static var kiroApp: Image { appIcon(for: .kiro) }

    static var safariApp: Image { appIcon(for: .safari) }
    static var chromeApp: Image { appIcon(for: .chrome) }
    static var firefoxApp: Image { appIcon(for: .firefox) }
    static var edgeApp: Image { appIcon(for: .edge) }
    static var arcApp: Image { appIcon(for: .arc) }

    static var finderApp: Image { appIcon(for: .finder) }
    static var terminalRealApp: Image { appIcon(for: .terminal) }
    static var previewRealApp: Image { appIcon(for: .preview) }
    static var textEditRealApp: Image { appIcon(for: .textEdit) }

    private static func appIcon(for appType: OpenAppType) -> Image {
        #if os(macOS)
        if let nsImage = appType.realIcon(useRealIcon: true) {
            return Image(nsImage: nsImage)
        }
        #endif
        return Image(systemName: appType.icon)
    }
}
