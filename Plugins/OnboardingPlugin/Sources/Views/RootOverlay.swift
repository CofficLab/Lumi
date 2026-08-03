import LumiKernel
import SwiftUI

// MARK: - RootOverlay

public struct RootOverlay<Content: View>: View {
    public let content: Content

    /// Aggregated onboarding pages from all enabled plugins, injected via
    /// `RootView`'s environment. Falls back to OnboardingPlugin's own pages
    /// when the environment value is empty (e.g., in previews).
    @Environment(\.onboardingPages) private var environmentPages

    // MARK: - ViewModel

    /// 使用 RuntimeBridge 中的 viewModel，确保在 onBoot/onReady 阶段初始化
    /// 这样可以保证使用正确的 storage 目录，而不是 fallback 到 Application Support
    ///
    /// 注意：不能直接 `@StateObject var viewModel = PluginViewModel()`
    /// 因为 PluginStore.init(pluginId:) 会立即创建目录。
    /// 必须延迟到 onAppear 时再创建 fallback，此时 kernel.storage 已注入正确路径。
    @State private var viewModel: PluginViewModel?

    // MARK: - 页面聚合

    private var pages: [OnboardingPageView] {
        guard !environmentPages.isEmpty else {
            return [
                OnboardingPageView(order: 0, view: AnyView(PluginManagementPage()))
            ]
        }
        return environmentPages
    }

    public var body: some View {
        Group {
            if let viewModel {
                PresentedContent(content: content, viewModel: viewModel, pages: pages)
            } else {
                content
            }
        }
            .onAppear {
                // 延迟创建 viewModel，避免在 View 属性初始化阶段就创建 Store 并触发 prepareDirectories()
                if viewModel == nil {
                    viewModel = RuntimeBridge.viewModel ?? PluginViewModel()
                }
                viewModel?.presentIfNeededOnLaunch()
            }
    }
}

/// Keeps the delayed ViewModel creation in the root overlay while ensuring
/// sheet presentation observes the ViewModel's @Published state.
private struct PresentedContent<Content: View>: View {
    let content: Content
    @ObservedObject var viewModel: PluginViewModel
    let pages: [OnboardingPageView]

    var body: some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .lumiShowOnboarding)) { notification in
                let forceReset = notification.userInfo?[LumiOnboardingNotification.resetKey] as? Bool ?? false
                viewModel.show(forceReset: forceReset)
            }
            .sheet(isPresented: $viewModel.isPresentingOnboarding) {
                SheetView(viewModel: viewModel, pages: pages)
            }
    }
}

// MARK: - SheetView

private struct SheetView: View {
    @ObservedObject var viewModel: PluginViewModel
    let pages: [OnboardingPageView]
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    public var body: some View {
        if pages.isEmpty {
            AnyView(EmptyView())
        } else {
            AnyView(buildSheet())
        }
    }

    @ViewBuilder
    private func buildSheet() -> some View {
        let pageIndex = safePageIndex
        let page = pages[pageIndex]
        let isLastPage = pageIndex == pages.count - 1

        ZStack {
            // 背景渐变
            backgroundGradient

            // 主内容
            VStack(spacing: 0) {
                // 顶部导航栏
                topBar

                // 分隔线
                Divider()
                    .opacity(0.5)

                // 内容区域 - 动态渲染插件提供的页面
                ScrollView(.vertical, showsIndicators: false) {
                    page.view
                        .padding(.horizontal, 32)
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                }

                // 底部分隔线
                Divider()
                    .opacity(0.5)

                // 底部操作栏
                bottomBar(isLastPage: isLastPage)
            }
        }
        .frame(width: 640, height: 550)
        .background(.clear)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(colorScheme == .dark ? 0.15 : 0.3),
                            .white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.5 : 0.2),
            radius: 40,
            x: 0,
            y: 20
        )
        .interactiveDismissDisabled()
        .alert(
            LumiPluginLocalization.string("Failed to save onboarding state", bundle: .module),
            isPresented: Binding(
                get: { viewModel.persistenceErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.persistenceErrorMessage = nil
                    }
                }
            )
        ) {
            Button(LumiPluginLocalization.string("OK", bundle: .module), role: .cancel) {}
        } message: {
            Text(viewModel.persistenceErrorMessage ?? "")
        }
    }

    // MARK: - 子视图

    /// 背景渐变
    private var backgroundGradient: some View {
        // Use a generic gradient for contributed pages (they don't expose gradient colors).
        LinearGradient(
            colors: [
                .accentColor.opacity(colorScheme == .dark ? 0.08 : 0.04),
                .accentColor.opacity(colorScheme == .dark ? 0.05 : 0.02),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    /// 顶部导航栏
    private var topBar: some View {
        HStack {
            Label(LumiPluginLocalization.string("Onboarding Guide", bundle: .module), systemImage: "graduationcap.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()

            // 步骤指示器
            stepIndicator

            Spacer()

            // 跳过按钮
            Button(LumiPluginLocalization.string("Skip", bundle: .module)) {
                viewModel.skip()
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.quinary.opacity(0.5))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    /// 步骤指示器
    private var stepIndicator: some View {
        let pageIndex = safePageIndex
        let activeColor = Color.accentColor

        return HStack(spacing: 6) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule()
                    .fill(
                        index == pageIndex
                            ? activeColor
                            : Color.secondary.opacity(index < pageIndex ? 0.4 : 0.15)
                    )
                    .frame(
                        width: index == pageIndex ? 24 : 8,
                        height: 6
                    )
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.8),
                        value: viewModel.currentStep
                    )
            }
        }
    }

    /// 底部操作栏
    private func bottomBar(isLastPage: Bool) -> some View {
        HStack {
            // 上一步按钮
            if viewModel.currentStep > 0 {
                Button {
                    viewModel.previousStep()
                } label: {
                    Label(LumiPluginLocalization.string("Previous", bundle: .module), systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.quinary.opacity(0.5))
                .clipShape(Capsule())
            }

            Spacer()

            // 下一步/开始使用按钮
            Button {
                if isLastPage {
                    viewModel.complete()
                } else {
                    viewModel.nextStep(totalSteps: pages.count)
                }
            } label: {
                HStack(spacing: 6) {
                    Text(isLastPage
                        ? LumiPluginLocalization.string("Get Started", bundle: .module)
                        : LumiPluginLocalization.string("Next", bundle: .module))
                        .font(.system(size: 13, weight: .semibold))

                    if !isLastPage {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var safePageIndex: Int {
        PageIndexing.clampedIndex(viewModel.currentStep, pageCount: pages.count)
    }
}

// MARK: - 预览

#Preview("新手引导") {
    RootOverlay(content: EmptyView())
}
