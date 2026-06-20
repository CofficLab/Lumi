import LumiCoreKit
import SwiftUI

/// Video Converter Plugin
///
/// Provides a view container for video format conversion using FFmpeg.
public enum VideoConverterPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optIn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .general
    public static let iconName = "video"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.video-converter",
        displayName: VideoConverterLocalization.string("Video Converter"),
        description: VideoConverterLocalization.string("Convert video formats using FFmpeg"),
        order: 70
    )

    public static var id: String { info.id }
    public static var displayName: String { info.displayName }
    public static var description: String { info.description }
    public static var order: Int { info.order }

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                VideoConverterMainView()
            }
        ]
    }
}
