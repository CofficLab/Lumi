import LumiCoreKit
import LumiUI
import SwiftUI

/// Video Converter Plugin
///
/// Provides a view container for video format conversion using FFmpeg.
public enum VideoConverterPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.video-converter",
        displayName: VideoConverterLocalization.string("Video Converter"),
        description: VideoConverterLocalization.string("Convert video formats using FFmpeg"),
        order: 70,
        category: .general,
        policy: .optIn,
        stage: .beta,
        iconName: "video",
    )

    public static var id: String { info.id }
    public static var displayName: String { info.displayName }
    public static var description: String { info.description }
    public static var order: Int { info.order }

    @MainActor
    public static func viewContainers(context: any LumiCoreAccessing) -> [LumiViewContainerItem] {
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

    @MainActor
    public static func onboardingPages(context: any LumiCoreAccessing) -> [AnyView] {
        [
            AnyView(
                PluginOnboardingPageView(
                    icon: iconName,
                    displayName: info.displayName,
                    description: info.description,
                    features: [
                        .init(
                            icon: "arrow.triangle.2.circlepath",
                            title: VideoConverterLocalization.string("Any format"),
                            description: VideoConverterLocalization.string("Convert clips between common formats")
                        ),
                        .init(
                            icon: "wand.and.stars",
                            title: VideoConverterLocalization.string("Presets"),
                            description: VideoConverterLocalization.string("Pick a target format and convert in bulk")
                        ),
                    ],
                    tip: VideoConverterLocalization.string("FFmpeg is required. Open Video Converter from the sidebar to start.")
                )
            )
        ]
    }
}
