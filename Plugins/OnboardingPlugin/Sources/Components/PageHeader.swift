import SwiftUI

// MARK: - PageHeader

/// Shared header section used by onboarding pages.
struct PageHeader: View {
    let icon: String
    let gradient: [Color]
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient.map { $0.opacity(0.15) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Convenience View Builder

@ViewBuilder
func headerSection(
    icon: String,
    gradient: [Color],
    title: String,
    subtitle: String
) -> some View {
    PageHeader(
        icon: icon,
        gradient: gradient,
        title: title,
        subtitle: subtitle
    )
}

#Preview("Page Header") {
    PageHeader(
        icon: "sparkles",
        gradient: [.blue, .purple],
        title: LumiPluginLocalization.string("Welcome to Lumi", bundle: .module),
        subtitle: LumiPluginLocalization.string("Your AI-powered personal desktop assistant", bundle: .module)
    )
    .padding()
    .frame(width: 560)
}
