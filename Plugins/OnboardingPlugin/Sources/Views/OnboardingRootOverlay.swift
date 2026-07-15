import Foundation
import LumiCoreKit
import os
import SuperLogKit
import SwiftUI

enum OnboardingPageIndexing {
    static func clampedIndex(_ index: Int, pageCount: Int) -> Int {
        guard pageCount > 0 else { return 0 }
        return min(max(index, 0), pageCount - 1)
    }
}

// MARK: - ViewModel

@MainActor
public final class OnboardingPluginViewModel: ObservableObject, SuperLog {
    // MARK: - 属性

    @Published var isPresentingOnboarding = false
    @Published var currentStep = 0
    @Published var isTransitioning = false
    @Published var persistenceErrorMessage: String?

    private let store: OnboardingPluginStore

    // MARK: - 初始化

    public init(store: OnboardingPluginStore = .init(pluginId: "Onboarding")) {
        self.store = store
    }

    // MARK: - 计算属性

    private var hasCompletedOnboarding: Bool {
        store.completed
    }

    // MARK: - 公开方法

    public func presentIfNeededOnLaunch() {
        guard !hasCompletedOnboarding else { return }
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        start()
    }

    public func start() {
        currentStep = 0
        isPresentingOnboarding = true
    }

    public func show(forceReset: Bool) {
        if forceReset {
            guard store.setCompleted(false) else {
                persistenceErrorMessage = LumiPluginLocalization.string("Failed to reset onboarding state. Please check if Lumi data directory is writable.", bundle: .module)
                return
            }
        }
        start()
    }

    public func skip() {
        complete()
    }

    public func complete() {
        guard store.setCompleted(true) else {
            persistenceErrorMessage = LumiPluginLocalization.string("Failed to save onboarding state. Please check if Lumi data directory is writable.", bundle: .module)
            return
        }
        isPresentingOnboarding = false
        currentStep = 0
    }

    public func nextStep(totalSteps: Int) {
        guard totalSteps > 0 else {
            complete()
            return
        }
        guard !isTransitioning else { return }

        currentStep = OnboardingPageIndexing.clampedIndex(currentStep, pageCount: totalSteps)
        if currentStep >= totalSteps - 1 {
            complete()
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isTransitioning = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.currentStep = OnboardingPageIndexing.clampedIndex(self.currentStep + 1, pageCount: totalSteps)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    self.isTransitioning = false
                }
            }
        }
    }

    public func previousStep() {
        guard !isTransitioning else { return }
        guard currentStep > 0 else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isTransitioning = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.currentStep = max(self.currentStep - 1, 0)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.isTransitioning = false
            }
        }
    }
}

// MARK: - Store

public final class OnboardingPluginStore: SuperLog {
    // MARK: - 属性

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.onboarding.store")
    private let fileManager = FileManager.default
    private let settingsURL: URL
    private let stateFileURL: URL
    private let corruptStateFileURL: URL

    // MARK: - 初始化

    public init(pluginId: String) {
        let root = (currentLumiCoreDataRootDirectory ?? lumiCoreFallbackDataRootDirectory)
            .appendingPathComponent(pluginId, isDirectory: true)
        self.settingsURL = root.appendingPathComponent("settings", isDirectory: true)
        self.stateFileURL = settingsURL.appendingPathComponent("onboarding_state.plist")
        self.corruptStateFileURL = settingsURL.appendingPathComponent("onboarding_state.corrupt.plist")
        prepareDirectories()
    }

    init(settingsDirectory: URL) {
        self.settingsURL = settingsDirectory
        self.stateFileURL = settingsURL.appendingPathComponent("onboarding_state.plist")
        self.corruptStateFileURL = settingsURL.appendingPathComponent("onboarding_state.corrupt.plist")
        prepareDirectories()
    }

    // MARK: - 公开方法

    public var completed: Bool {
        get { readCompletedFlag() }
        set { setCompleted(newValue) }
    }

    @discardableResult
    public func setCompleted(_ completed: Bool) -> Bool {
        writeCompletedFlag(completed)
    }

    // MARK: - 私有方法

    private func prepareDirectories() {
        do {
            try fileManager.createDirectory(at: settingsURL, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("\(Self.t)Create onboarding settings directory failed: \(error.localizedDescription)")
        }
    }

    private func readCompletedFlag() -> Bool {
        guard fileManager.fileExists(atPath: stateFileURL.path) else {
            return false
        }

        do {
            let data = try Data(contentsOf: stateFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                Self.logger.error("\(Self.t)Read onboarding state failed: root plist is not a dictionary")
                quarantineCorruptState()
                return false
            }
            return dict["completed"] as? Bool ?? false
        } catch {
            Self.logger.error("\(Self.t)Read onboarding state failed: \(error.localizedDescription)")
            quarantineCorruptState()
            return false
        }
    }

    @discardableResult
    private func writeCompletedFlag(_ completed: Bool) -> Bool {
        let payload: [String: Any] = [
            "completed": completed,
            "updatedAt": Date()
        ]

        let data: Data
        do {
            data = try PropertyListSerialization.data(fromPropertyList: payload, format: .binary, options: 0)
        } catch {
            Self.logger.error("\(Self.t)Encode onboarding state failed: \(error.localizedDescription)")
            return false
        }

        let tempURL = settingsURL.appendingPathComponent("onboarding_state.tmp")
        do {
            try fileManager.createDirectory(at: settingsURL, withIntermediateDirectories: true)
            try data.write(to: tempURL, options: .atomic)
            if fileManager.fileExists(atPath: stateFileURL.path) {
                _ = try fileManager.replaceItemAt(stateFileURL, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: stateFileURL)
            }
            return true
        } catch {
            Self.logger.error("\(Self.t)Persist onboarding state failed: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tempURL)
            return false
        }
    }

    private func quarantineCorruptState() {
        guard fileManager.fileExists(atPath: stateFileURL.path) else { return }

        do {
            if fileManager.fileExists(atPath: corruptStateFileURL.path) {
                try fileManager.removeItem(at: corruptStateFileURL)
            }
            try fileManager.moveItem(at: stateFileURL, to: corruptStateFileURL)
        } catch {
            Self.logger.error("\(Self.t)Quarantine corrupt onboarding state failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - RootOverlay

public struct OnboardingRootOverlay<Content: View>: View {
    public let content: Content

    @StateObject private var viewModel = OnboardingPluginViewModel()

    /// Aggregated onboarding pages from all enabled plugins, injected via
    /// `RootView`'s environment. Falls back to OnboardingPlugin's own pages
    /// when the environment value is empty (e.g., in previews).
    @Environment(\.onboardingPages) private var environmentPages

    // MARK: - 页面聚合

    private var pages: [OnboardingPageView] {
        guard !environmentPages.isEmpty else {
            let fallback = OnboardingPlugin.onboardingPages(context: LumiPluginContext(
                activeSectionID: "preview",
                activeSectionTitle: "Preview"
            ))
            return fallback.enumerated().map { (index, view) in
                OnboardingPageView(order: index, view: view)
            }
        }
        return environmentPages
    }

    public var body: some View {
        content
            .onAppear {
                viewModel.presentIfNeededOnLaunch()
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiShowOnboarding)) { notification in
                let forceReset = notification.userInfo?[LumiOnboardingNotification.resetKey] as? Bool ?? false
                viewModel.show(forceReset: forceReset)
            }
            .sheet(isPresented: $viewModel.isPresentingOnboarding) {
                OnboardingSheetView(viewModel: viewModel, pages: pages)
            }
    }
}

// MARK: - SheetView

private struct OnboardingSheetView: View {
    @ObservedObject var viewModel: OnboardingPluginViewModel
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
        .frame(width: 640, height: 480)
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
        OnboardingPageIndexing.clampedIndex(viewModel.currentStep, pageCount: pages.count)
    }
}

// MARK: - 预览

#Preview("新手引导") {
    OnboardingRootOverlay(content: EmptyView())
}
