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
            title: String(localized: "Welcome to Lumi", table: "AgentOnboardingPlugin"),
            subtitle: String(localized: "An AI workspace designed for developers", table: "AgentOnboardingPlugin"),
            bullets: [
                String(localized: "Ask, execute, and review in one window", table: "AgentOnboardingPlugin"),
                String(localized: "Context is preserved by task, reducing repetitive communication", table: "AgentOnboardingPlugin"),
                String(localized: "Support for parallel conversations without interference", table: "AgentOnboardingPlugin")
            ]
        ),
        Page(
            icon: "rectangle.3.group.bubble.left",
            title: String(localized: "Agent / App Two Modes", table: "AgentOnboardingPlugin"),
            subtitle: String(localized: "Choose the best approach for your task", table: "AgentOnboardingPlugin"),
            bullets: [
                String(localized: "Agent Mode: For complex tasks with tool calls and multi-step reasoning", table: "AgentOnboardingPlugin"),
                String(localized: "App Mode: For plugin capabilities with quick single-point operations", table: "AgentOnboardingPlugin"),
                String(localized: "After switching modes, check the top tip to see available capabilities", table: "AgentOnboardingPlugin")
            ]
        ),
        Page(
            icon: "keyboard",
            title: String(localized: "Quick Start", table: "AgentOnboardingPlugin"),
            subtitle: String(localized: "Do these 3 things to get into the workflow", table: "AgentOnboardingPlugin"),
            bullets: [
                String(localized: "Create a new conversation and start with a real question", table: "AgentOnboardingPlugin"),
                String(localized: "Click \"View Guide\" in empty state to review anytime", table: "AgentOnboardingPlugin"),
                String(localized: "Common shortcuts: Cmd+N new conversation, Cmd+, open settings", table: "AgentOnboardingPlugin")
            ]
        )
    ]

    var body: some View {
        let page = pages[viewModel.currentStep]

        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Label(String(localized: "Guide", table: "AgentOnboardingPlugin"), systemImage: "graduationcap")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(String(localized: "Skip", table: "AgentOnboardingPlugin")) { viewModel.skip() }
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
                    Button(String(localized: "Previous", table: "AgentOnboardingPlugin")) { viewModel.previousStep() }
                }

                Button(viewModel.currentStep == pages.count - 1 ? String(localized: "Get Started", table: "AgentOnboardingPlugin") : String(localized: "Next", table: "AgentOnboardingPlugin")) {
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
