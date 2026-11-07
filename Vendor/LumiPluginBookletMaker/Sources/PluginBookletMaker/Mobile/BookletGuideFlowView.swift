#if os(iOS)
import SwiftUI

/// 引导流程覆盖的三种工具。
enum BookletGuideKind: String, Identifiable, Equatable {
    case booklet
    case split
    case merge

    var id: String { rawValue }

    /// 引导页数：booklet 与 merge 分两步（介绍 → 准备），split 一步讲完。
    var pageCount: Int {
        switch self {
        case .booklet, .merge: 2
        case .split: 1
        }
    }

    /// 进度条分母：对应工具进入工作台后的阶段数，预先告知后面还有多少步。
    var stepCount: Int {
        switch self {
        case .booklet: 6
        case .split: 3
        case .merge: 3
        }
    }

    /// 合并至少需要两个文件，内置示例演示不了，因此不提供「使用示例」入口。
    var supportsSampleDocument: Bool { self != .merge }

    init(_ tool: BookletMakerMobileFeature.Tool) {
        switch tool {
        case .booklet: self = .booklet
        case .split: self = .split
        case .merge: self = .merge
        }
    }
}

/// 全屏分步引导：一屏一件事，讲完再进入工作台。
///
/// 由首页的工具卡片打开，通过 `fullScreenCover` 覆盖整个界面；
/// 用户选好工具后引导页负责收集「打开文件 / 用示例」这一步，
/// 完成后由根视图推进到对应工具的工作台。
struct BookletGuideFlowView: View {
    let kind: BookletGuideKind
    /// 打开时落在第几屏。
    ///
    /// 帮助页的「再看一次引导」可以从任意一屏重新开始；其余入口都从第 1 屏。
    let initialPage: Int
    let onOpenPDF: () -> Void
    let onUseSample: () -> Void
    let onDismiss: () -> Void

    @State private var page: Int

    init(
        kind: BookletGuideKind,
        initialPage: Int = 1,
        onOpenPDF: @escaping () -> Void,
        onUseSample: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.kind = kind
        self.initialPage = initialPage
        self.onOpenPDF = onOpenPDF
        self.onUseSample = onUseSample
        self.onDismiss = onDismiss
        _page = State(initialValue: min(max(initialPage, 1), kind.pageCount))
    }

    /// 进度条上的当前步：booklet / merge 的两步对应 1 与末步之前的进度，
    /// split 只有一步，恒显示第 1 步。
    private var visibleStep: Int {
        kind == .split ? 1 : page
    }

    /// 引导页自身的位置（1-based），用于「上一步 / 下一步」判断。
    private var isLastPage: Bool { page >= kind.pageCount }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                // 正文必须可滚动：`Spacer` 会把内容按视口高度均分，一旦文案
                // 换行导致内容超出可用高度，`actionBar` 的底部按钮就会被挤出
                // 屏幕之外——在小屏 iPhone 上实测「使用示例」的 frame 顶端落在
                // y≈772，而窗口可视区只到 y≈738，按钮永远点不到。滚动视图让
                // 内容变长时用户能滑到底，而不是被裁掉。
                ScrollView {
                    VStack(spacing: 0) {
                        BookletMobileProgressView(current: visibleStep, total: kind.stepCount)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)

                        Spacer(minLength: 18)
                        illustration
                            .padding(.horizontal, 24)
                        Spacer(minLength: 20)

                        VStack(alignment: .leading, spacing: 9) {
                            Text(pageTitle)
                                .font(.title2.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(pageDescription)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: 560, alignment: .leading)
                        .padding(.horizontal, 26)
                        .accessibilityIdentifier("guide.text")

                        actionBar
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    // 内容不足一屏时仍按整屏高度排版，保持插图居中的观感；
                    // 超出时 ScrollView 自然接管滚动。
                    .frame(minHeight: geometry.size.height)
                }
                // `scrollBounceBehavior` 是 macOS 13.3 才有的 API，最低支持版本
                // 是 13.1，因此需要按版本条件应用；13.1 上退化为系统默认回弹行为。
                .modifier(ContentSizeScrollBounceModifier())
                .background(BookletMobileStyle.canvas.ignoresSafeArea())
                .navigationTitle(kindTitle)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .tint(BookletMobileStyle.accent)
        .interactiveDismissDisabled()
    }

    // MARK: - Copy

    private var kindTitle: String {
        switch kind {
        case .booklet: BookletLocalization.string("Make a Booklet")
        case .split: BookletLocalization.string("Split a PDF")
        case .merge: BookletLocalization.string("Merge PDFs")
        }
    }

    private var pageTitle: String {
        switch (kind, isLastPage) {
        case (.booklet, false): BookletLocalization.string("Turn a PDF into a folded booklet")
        case (.booklet, true): BookletLocalization.string("Ready to make your booklet?")
        case (.split, _): BookletLocalization.string("Split a PDF into separate files")
        case (.merge, false): BookletLocalization.string("Combine several PDFs into one")
        case (.merge, true): BookletLocalization.string("Ready to merge your PDFs?")
        }
    }

    private var pageDescription: String {
        switch (kind, isLastPage) {
        case (.booklet, false):
            BookletLocalization.string(
                "Choose a PDF and the app will reorder its pages for double-sided printing. Fold the printed sheets to make a booklet."
            )
        case (.booklet, true):
            BookletLocalization.string(
                "Choose a PDF, check the paper and print layout, then export. For best results, test one sheet before printing the whole booklet."
            )
        case (.split, _):
            BookletLocalization.string(
                "Mark page breaks in a document. Each range becomes a separate PDF you can share."
            )
        case (.merge, false):
            BookletLocalization.string(
                "Pick two or more PDFs and arrange them in the order you want. They become a single file with all pages in sequence."
            )
        case (.merge, true):
            BookletLocalization.string(
                "Add your PDFs, drag them into the right order, then merge. Nothing is uploaded — every file stays on this device."
            )
        }
    }

    // MARK: - Illustration

    @ViewBuilder
    private var illustration: some View {
        switch kind {
        case .booklet:
            VStack(spacing: 12) {
                BookletPagePairIllustration(left: "1", right: "4", showsArrow: true)
                Label(
                    BookletLocalization.string("Pages are reordered for printing"),
                    systemImage: "arrow.left.arrow.right"
                )
                .font(.footnote.weight(.medium))
                .foregroundStyle(BookletMobileStyle.accent)
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(BookletMobileStyle.accent)
                    .frame(width: 84, height: 70)
                    .background(BookletMobileStyle.softAccent, in: RoundedRectangle(cornerRadius: 16))
            }
        case .split:
            VStack(spacing: 18) {
                HStack(spacing: 9) {
                    guidePage("1")
                    Image(systemName: "scissors")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(BookletMobileStyle.accent)
                    guidePage("2")
                    guidePage("3")
                }
                Image(systemName: "arrow.down")
                    .foregroundStyle(BookletMobileStyle.accent.opacity(0.65))
                HStack(spacing: 12) {
                    Label(BookletLocalization.string("PDF file 1"), systemImage: "doc.text")
                    Label(BookletLocalization.string("PDF file 2"), systemImage: "doc.text")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(BookletMobileStyle.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(22)
            .background(BookletMobileStyle.softAccent, in: RoundedRectangle(cornerRadius: 18))
        case .merge:
            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    guidePage("A")
                    guidePage("B")
                    guidePage("C")
                }
                Image(systemName: "arrow.down")
                    .foregroundStyle(BookletMobileStyle.accent.opacity(0.65))
                HStack(spacing: 12) {
                    Label(BookletLocalization.string("One PDF"), systemImage: "doc.text.fill")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(BookletMobileStyle.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(22)
            .background(BookletMobileStyle.softAccent, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func guidePage(_ number: String) -> some View {
        Text(number)
            .font(.headline)
            .foregroundStyle(BookletMobileStyle.paperInk)
            .frame(width: 52, height: 72)
            .background(.white, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.12), lineWidth: 0.7))
            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    if page > 1 {
                        page -= 1
                    } else {
                        onDismiss()
                    }
                } label: {
                    Label(
                        page > 1
                            ? BookletLocalization.string("Previous")
                            : BookletLocalization.string("Close"),
                        systemImage: page > 1 ? "chevron.left" : "xmark"
                    )
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("guide.close")

                if isLastPage {
                    Button(action: onOpenPDF) {
                        Label(BookletLocalization.string("Open PDF"), systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("guide.openPDF")
                } else {
                    Button {
                        page += 1
                    } label: {
                        Label(BookletLocalization.string("Next"), systemImage: "arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("guide.next")
                }
            }

            if isLastPage, kind.supportsSampleDocument {
                Button(action: onUseSample) {
                    Label(BookletLocalization.string("Use Sample PDF"), systemImage: "book")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("guide.useSample")
            }
        }
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
    }
}

/// macOS 13.3+ 才支持按内容尺寸决定回弹行为；13.1 上不做任何处理。
private struct ContentSizeScrollBounceModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 13.3, *) {
            content.scrollBounceBehavior(.basedOnSize)
        } else {
            content
        }
    }
}
#endif
