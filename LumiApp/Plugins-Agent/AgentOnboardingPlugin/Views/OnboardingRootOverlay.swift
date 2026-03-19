import Foundation
import SwiftUI

private enum OnboardingNotification {
    static let show = Notification.Name("AgentOnboarding.Show")
}

@MainActor
final class OnboardingPluginViewModel: ObservableObject {
    @Published var isPresentingOnboarding = false
    @Published var currentStep = 0

    private let store: OnboardingPluginStore

    init(store: OnboardingPluginStore = .init(pluginId: "AgentOnboarding")) {
        self.store = store
    }

    private var hasCompletedOnboarding: Bool {
        store.completed
    }

    func presentIfNeededOnLaunch() {
        guard !hasCompletedOnboarding else { return }
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        start()
    }

    func start() {
        currentStep = 0
        isPresentingOnboarding = true
    }

    func show(forceReset: Bool) {
        if forceReset {
            store.completed = false
        }
        start()
    }

    func skip() {
        complete()
    }

    func complete() {
        store.completed = true
        isPresentingOnboarding = false
        currentStep = 0
    }

    func nextStep() {
        if currentStep >= 2 {
            complete()
        } else {
            currentStep += 1
        }
    }

    func previousStep() {
        guard currentStep > 0 else { return }
        currentStep -= 1
    }
}

final class OnboardingPluginStore {
    private let fileManager = FileManager.default
    private let settingsURL: URL
    private let stateFileURL: URL

    init(pluginId: String) {
        let root = AppConfig.getDBFolderURL()
            .appendingPathComponent(pluginId, isDirectory: true)
        self.settingsURL = root.appendingPathComponent("settings", isDirectory: true)
        self.stateFileURL = settingsURL.appendingPathComponent("onboarding_state.plist")
        prepareDirectories()
    }

    var completed: Bool {
        get { readCompletedFlag() }
        set { writeCompletedFlag(newValue) }
    }

    private func prepareDirectories() {
        try? fileManager.createDirectory(at: settingsURL, withIntermediateDirectories: true)
    }

    private func readCompletedFlag() -> Bool {
        guard fileManager.fileExists(atPath: stateFileURL.path),
              let data = try? Data(contentsOf: stateFileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any],
              let completed = dict["completed"] as? Bool else {
            return false
        }
        return completed
    }

    private func writeCompletedFlag(_ completed: Bool) {
        let payload: [String: Any] = [
            "completed": completed,
            "updatedAt": Date()
        ]

        guard let data = try? PropertyListSerialization.data(fromPropertyList: payload, format: .binary, options: 0) else {
            return
        }

        let tempURL = settingsURL.appendingPathComponent("onboarding_state.tmp")
        do {
            try data.write(to: tempURL, options: .atomic)
            if fileManager.fileExists(atPath: stateFileURL.path) {
                _ = try? fileManager.replaceItemAt(stateFileURL, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: stateFileURL)
            }
        } catch {
            try? fileManager.removeItem(at: tempURL)
        }
    }
}

struct OnboardingRootOverlay<Content: View>: View {
    let content: Content

    @StateObject private var viewModel = OnboardingPluginViewModel()

    var body: some View {
        content
            .onAppear {
                viewModel.presentIfNeededOnLaunch()
            }
            .onReceive(NotificationCenter.default.publisher(for: OnboardingNotification.show)) { notification in
                let forceReset = notification.userInfo?["reset"] as? Bool ?? false
                viewModel.show(forceReset: forceReset)
            }
            .sheet(isPresented: $viewModel.isPresentingOnboarding) {
                OnboardingSheetView(viewModel: viewModel)
            }
    }
}

private struct OnboardingSheetView: View {
    @ObservedObject var viewModel: OnboardingPluginViewModel

    private struct Page: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let bullets: [String]
    }

    private let pages: [Page] = [
        Page(
            icon: "sparkles",
            title: "欢迎使用 Lumi",
            subtitle: "一个为开发者设计的 AI 工作台",
            bullets: [
                "在一个窗口完成提问、执行与复盘",
                "按任务维度沉淀上下文，减少重复沟通",
                "支持多会话并行，互不干扰"
            ]
        ),
        Page(
            icon: "rectangle.3.group.bubble.left",
            title: "Agent / App 两种模式",
            subtitle: "根据任务目标选择最合适的工作方式",
            bullets: [
                "Agent 模式：面向复杂任务，支持工具调用与多步骤推理",
                "App 模式：面向插件能力，快速执行单点操作",
                "模式切换后，建议先看顶部提示了解可用能力"
            ]
        ),
        Page(
            icon: "keyboard",
            title: "快速上手",
            subtitle: "先做 3 件事就能进入工作流",
            bullets: [
                "新建会话，输入一个真实问题开始",
                "在空状态点击“查看新手引导”可随时回看",
                "常用快捷键：Cmd+N 新建会话，Cmd+, 打开设置"
            ]
        )
    ]

    var body: some View {
        let page = pages[viewModel.currentStep]

        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Label("新手引导", systemImage: "graduationcap")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("跳过") { viewModel.skip() }
                    .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: page.icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.accent)

                Text(page.title)
                    .font(.system(size: 28, weight: .bold))

                Text(page.subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(page.bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.green)
                            .padding(.top, 4)
                        Text(bullet)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == viewModel.currentStep ? Color.accentColor : Color.secondary.opacity(0.25))
                            .frame(width: index == viewModel.currentStep ? 22 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.currentStep)
                    }
                }

                Spacer()

                if viewModel.currentStep > 0 {
                    Button("上一步") { viewModel.previousStep() }
                }

                Button(viewModel.currentStep == pages.count - 1 ? "开始使用" : "下一步") {
                    viewModel.nextStep()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(width: 640, height: 440)
        .interactiveDismissDisabled()
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.background)
        }
    }
}

#Preview {
    OnboardingRootOverlay(content: EmptyView())
}
