#if os(iOS)
import SwiftUI

/// 首页：一屏列出三个工具，点卡片进入全屏引导。
///
/// 工具的具体操作说明放在引导页，首页只回答「能做什么」，避免一进来
/// 就面对文件选择器。
struct BookletWelcomeView: View {
    @ObservedObject var feature: BookletMakerMobileFeature
    let onChooseTool: (BookletMakerMobileFeature.Tool) -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    toolCard(
                        tool: .booklet,
                        title: BookletLocalization.string("Make a Booklet"),
                        subtitle: BookletLocalization.string(
                            "Reorder pages for folded, double-sided printing."
                        ),
                        illustration: .booklet
                    )

                    toolCard(
                        tool: .split,
                        title: BookletLocalization.string("Split a PDF"),
                        subtitle: BookletLocalization.string(
                            "Mark page breaks and export separate files."
                        ),
                        illustration: .split
                    )

                    toolCard(
                        tool: .merge,
                        title: BookletLocalization.string("Merge PDFs"),
                        subtitle: BookletLocalization.string(
                            "Combine several PDFs into one file, in any order."
                        ),
                        illustration: .merge
                    )

                    if let message = feature.sessionErrorMessage {
                        sessionErrorBanner(message)
                    }
                    Spacer(minLength: 24)
                    privacyNotice
                }
                .frame(maxWidth: 620)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
            }
        }
        .background(BookletMobileStyle.canvas)
        .navigationTitle(BookletLocalization.string("Booklet Maker"))
        .navigationBarTitleDisplayMode(.inline)
        // 导航栏工具栏由根视图统一挂载（首页与工具页共用 `documentMenu`），
        // 这里不再自带一份，避免同一屏出现两个「更多」菜单。
    }

    private enum Illustration: Equatable {
        case booklet
        case split
        case merge
    }

    private func toolCard(
        tool: BookletMakerMobileFeature.Tool,
        title: String,
        subtitle: String,
        illustration: Illustration
    ) -> some View {
        Button { onChooseTool(tool) } label: {
            BookletMobileStyle.cardBackground {
                VStack(alignment: .leading, spacing: 13) {
                    HStack(spacing: 12) {
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(BookletMobileStyle.accent)
                            .frame(width: 46, height: 46)
                            .background(BookletMobileStyle.softAccent, in: RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }

                    switch illustration {
                    case .booklet:
                        bookletIllustration
                    case .split:
                        splitIllustration
                    case .merge:
                        mergeIllustration
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("welcome.\(tool.rawValue)Tool")
    }

    private var bookletIllustration: some View {
        HStack(spacing: 14) {
            HStack(spacing: 4) {
                ForEach(1...4, id: \.self) { number in
                    pageSymbol("\(number)", width: 19, height: 26)
                }
            }

            illustrationArrow

            HStack(spacing: 0) {
                pageSymbol("4", width: 29, height: 34)
                Rectangle()
                    .fill(Color.secondary.opacity(0.28))
                    .frame(width: 1, height: 34)
                pageSymbol("1", width: 29, height: 34)
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.12), lineWidth: 0.7))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(illustrationBackground, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityHidden(true)
    }

    private var splitIllustration: some View {
        HStack(spacing: 16) {
            pageSymbol(width: 30, height: 40)
                .overlay {
                    GeometryReader { geometry in
                        Path { path in
                            let y = geometry.size.height / 2
                            path.move(to: CGPoint(x: 4, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width - 4, y: y))
                        }
                        .stroke(
                            BookletMobileStyle.accent.opacity(0.72),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                        )
                    }
                }
            illustrationArrow
            HStack(spacing: 5) {
                pageSymbol(width: 16, height: 32)
                pageSymbol(width: 16, height: 32)
                pageSymbol(width: 16, height: 32)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(illustrationBackground, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityHidden(true)
    }

    private var mergeIllustration: some View {
        HStack(spacing: 10) {
            pageSymbol("A", width: 20, height: 28)
            pageSymbol("B", width: 20, height: 28)
            illustrationArrow
            HStack(spacing: 0) {
                pageSymbol(width: 17, height: 38)
                pageSymbol(width: 17, height: 38)
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.12), lineWidth: 0.7))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(illustrationBackground, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityHidden(true)
    }

    private var illustrationBackground: Color {
        Color.primary.opacity(0.035)
    }

    private var illustrationArrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.tertiary)
    }

    private func pageSymbol(_ number: String? = nil, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if let number {
                Text(number)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(BookletMobileStyle.paperInk)
            }
        }
        .frame(width: width, height: height)
        .background(.white, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.12), lineWidth: 0.7))
    }

    private var privacyNotice: some View {
        Label {
            Text(BookletLocalization.string(
                "Your documents stay on this device. Nothing is uploaded."
            ))
        } icon: {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(BookletMobileStyle.privacyAccent)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func sessionErrorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(.subheadline)
            Spacer()
            Button {
                feature.dismissSessionError()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel(BookletLocalization.string("Dismiss"))
        }
        .padding(12)
        .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}
#endif
