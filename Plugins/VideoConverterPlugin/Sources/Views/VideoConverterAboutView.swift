import LumiUI
import SwiftUI

// MARK: - About View

struct VideoConverterAboutView: View {
    @Environment(\.locale) private var locale
    @LumiTheme private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Feature Highlights
                FeatureHighlight(
                    icon: "arrow.triangle.2.circlepath",
                    title: L("Video Conversion"),
                    description: L("Convert video files between popular formats like MP4, MOV, AVI, MKV, and more")
                )

                FeatureHighlight(
                    icon: "slider.horizontal.3",
                    title: L("Quality Settings"),
                    description: L("Adjust video quality, resolution, and codec settings for optimal output")
                )

                FeatureHighlight(
                    icon: "bolt.fill",
                    title: L("FFmpeg Powered"),
                    description: L("Powered by FFmpeg for fast and reliable video processing")
                )

                FeatureHighlight(
                    icon: "doc.on.doc",
                    title: L("Batch Processing"),
                    description: L("Convert multiple files in a queue with progress tracking")
                )

                // How It Works
                HowItWorksCard(
                    title: coreL("about.section.howItWorks"),
                    steps: [
                        L("Drag and drop video files or click to select"),
                        L("Choose target format and quality settings"),
                        L("Click convert to start processing"),
                        L("Find converted files in the output directory")
                    ]
                )

                // Supported Formats
                SupportedFormatsCard(
                    title: L("Supported Formats"),
                    formats: [
                        ("MP4", "H.264/H.265 video, AAC audio"),
                        ("MOV", "QuickTime format with excellent quality"),
                        ("AVI", "Windows-compatible video format"),
                        ("MKV", "Matroska, supports multiple audio tracks"),
                        ("WebM", "Web-optimized format, VP8/VP9"),
                        ("GIF", "Animated image export")
                    ]
                )

                // Tips
                TipsCard(
                    title: coreL("about.section.tips"),
                    tips: [
                        L("Use H.265 for smaller file sizes with same quality"),
                        L("Lower resolution saves space for mobile devices"),
                        L("Check FFmpeg installation in system preferences")
                    ]
                )
            }
            .padding()
        }
    }

    private func L(_ key: String, locale: Locale = .current) -> String {
        LumiPluginLocalization.string(key, bundle: .module, locale: locale)
    }

    private func coreL(_ key: String) -> String {
        switch key {
        case "about.section.howItWorks":
            return LumiPluginLocalization.string("How It Works", bundle: .module, locale: locale)
        case "about.section.tips":
            return LumiPluginLocalization.string("Tips", bundle: .module, locale: locale)
        default:
            return key
        }
    }
}

// MARK: - Feature Highlight

private struct FeatureHighlight: View {
    @LumiTheme private var theme
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(theme.primary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(theme.primary.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .appSurface(style: .subtle, cornerRadius: 8)
    }
}

// MARK: - How It Works Card

private struct HowItWorksCard: View {
    @LumiTheme private var theme
    let title: String
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.primary)
                            .frame(width: 22, height: 22)
                            .background(
                                Circle()
                                    .fill(theme.primary.opacity(0.15))
                            )

                        Text(step)
                            .font(.system(size: 13))
                            .foregroundColor(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .appSurface(style: .subtle, cornerRadius: 8)
    }
}

// MARK: - Supported Formats Card

private struct SupportedFormatsCard: View {
    @LumiTheme private var theme
    let title: String
    let formats: [(String, String)]

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(formats, id: \.0) { format in
                    HStack(spacing: 10) {
                        Image(systemName: "film")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.primary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(format.0)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.textPrimary)

                            Text(format.1)
                                .font(.system(size: 10))
                                .foregroundColor(theme.textSecondary)
                                .lineLimit(2)
                        }

                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.overlay)
                    )
                }
            }
        }
        .padding(14)
        .appSurface(style: .subtle, cornerRadius: 8)
    }
}

// MARK: - Tips Card

private struct TipsCard: View {
    @LumiTheme private var theme
    let title: String
    let tips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.primary)
                            .frame(width: 16)

                        Text(tip)
                            .font(.system(size: 13))
                            .foregroundColor(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .appSurface(style: .subtle, cornerRadius: 8)
    }
}
