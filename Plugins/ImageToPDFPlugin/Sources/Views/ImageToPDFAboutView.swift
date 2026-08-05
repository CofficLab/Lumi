import LumiUI
import SwiftUI

// MARK: - About View

/// Plugin-detail panel shown in the plugin manager.
struct ImageToPDFAboutView: View {
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FeatureHighlight(
                    icon: "photo.on.rectangle.angled",
                    title: L("Image to PDF"),
                    description: L("Convert dropped images to single-page PDFs that preserve the original size and orientation.")
                )
                FeatureHighlight(
                    icon: "square.grid.3x3",
                    title: L("Batch Conversion"),
                    description: L("Drop one or many images at once; each becomes its own PDF in the output list.")
                )
                FeatureHighlight(
                    icon: "square.and.arrow.up",
                    title: L("Export Anywhere"),
                    description: L("Pick a destination folder and export every converted PDF at once, or open them individually.")
                )

                HowItWorksCard(
                    title: L("How It Works"),
                    steps: [
                        L("Drag and drop image files into the drop zone"),
                        L("Click Convert to produce a PDF for each image"),
                        L("Preview, open, or reveal any PDF in the list"),
                        L("Click Export to… and choose a folder to save all PDFs")
                    ]
                )

                TipsCard(
                    title: L("Tips"),
                    tips: [
                        L("PDFs keep the original image size — no resizing or compression"),
                        L("Supported formats: PNG, JPEG, HEIC, TIFF, BMP, GIF and more"),
                        L("Re-converting replaces the previous PDFs in the output list")
                    ]
                )
            }
            .padding()
        }
    }

    private func L(_ key: String, locale: Locale = .current) -> String {
        ImageToPDFLocalization.string(key)
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
                    Circle().fill(theme.primary.opacity(0.1))
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
                                Circle().fill(theme.primary.opacity(0.15))
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