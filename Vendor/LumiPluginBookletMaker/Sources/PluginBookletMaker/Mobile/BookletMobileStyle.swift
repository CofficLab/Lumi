#if os(iOS)
import SwiftUI
import UIKit

enum BookletMobileStyle {
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.55, green: 0.72, blue: 0.98, alpha: 1)
            : UIColor(red: 30.0 / 255.0, green: 58.0 / 255.0, blue: 138.0 / 255.0, alpha: 1)
    })
    static let actionFill = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.19, green: 0.34, blue: 0.53, alpha: 1)
            : UIColor(red: 30.0 / 255.0, green: 58.0 / 255.0, blue: 138.0 / 255.0, alpha: 1)
    })
    static let paperInk = Color(red: 30.0 / 255.0, green: 58.0 / 255.0, blue: 138.0 / 255.0)
    static let privacyAccent = Color(uiColor: .systemGreen)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let softAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.23, blue: 0.34, alpha: 1)
            : UIColor(red: 30.0 / 255.0, green: 58.0 / 255.0, blue: 138.0 / 255.0, alpha: 0.08)
    })
    private static let cardOutline = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.09)
            : UIColor.black.withAlphaComponent(0.045)
    })

    static func cardBackground<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(16)
            .background(card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(cardOutline, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.035), radius: 5, y: 2)
    }
}

struct BookletMobileProgressView: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 9) {
            HStack(spacing: 4) {
                ForEach(1...max(total, 1), id: \.self) { step in
                    Capsule()
                        .fill(step <= current ? BookletMobileStyle.accent : BookletMobileStyle.accent.opacity(0.16))
                        .frame(height: 4)
                }
            }
            Text(BookletLocalization.string("%lld/%lld", Int64(current), Int64(total)))
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(BookletLocalization.string("Step %lld of %lld", Int64(current), Int64(total)))
    }
}

struct BookletPagePairIllustration: View {
    let left: String
    let right: String
    var showsArrow = true

    var body: some View {
        HStack(spacing: 11) {
            miniPage(left)
            if showsArrow {
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BookletMobileStyle.accent.opacity(0.65))
            }
            HStack(spacing: 1) {
                miniPage(left)
                miniPage(right)
            }
            .overlay(alignment: .center) {
                Rectangle()
                    .fill(BookletMobileStyle.accent.opacity(0.23))
                    .frame(width: 1)
            }
        }
        .padding(14)
        .background(BookletMobileStyle.softAccent, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityHidden(true)
    }

    private func miniPage(_ number: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(BookletMobileStyle.accent.opacity(0.6))
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.secondary.opacity(0.17))
                .frame(height: 3)
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.secondary.opacity(0.13))
                .frame(height: 3)
            Spacer(minLength: 2)
            Text(number)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BookletMobileStyle.paperInk)
        }
        .padding(8)
        .frame(width: 48, height: 68)
        .background(.white, in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.12), lineWidth: 0.7))
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }
}
#endif
