import ProviderOnboarding
import SwiftUI

/// Onboarding Provider 的局部观察模型。页面注册/撤销只刷新 onboarding 宿主，
/// 不会触发主窗口或系统菜单的重建。
@MainActor
final class OnboardingPagesModel: ObservableObject {
    let provider: (any OnboardingProviding)?
    @Published private(set) var pages: [OnboardingPageItem]
    private var observer: (any OnboardingObserverHandle)?

    init(provider: (any OnboardingProviding)?) {
        self.provider = provider
        self.pages = provider?.allPages ?? []
        self.observer = provider?.addObserver { [weak self] _ in
            guard let self else { return }
            self.pages = self.provider?.allPages ?? []
        }
    }
}

/// V2 first-run onboarding presenter. Pages are registered by plugins through
/// `OnboardingProviding`; this host owns persisted completion and replay.
struct OnboardingHost<Content: View>: View {
    let content: Content
    let provider: (any OnboardingProviding)?
    @StateObject private var pagesModel: OnboardingPagesModel
    @AppStorage("com.coffic.lumi.onboarding.completed") private var completed = false
    @State private var isPresented = false
    @State private var pageIndex = 0

    init(content: Content, provider: (any OnboardingProviding)?) {
        self.content = content
        self.provider = provider
        _pagesModel = StateObject(wrappedValue: OnboardingPagesModel(provider: provider))
    }

    private var pages: [OnboardingPageItem] {
        pagesModel.pages
    }

    var body: some View {
        content
            .onAppear {
                guard !completed, !pages.isEmpty else { return }
                isPresented = true
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("Onboarding.Show"))) { notification in
                if notification.userInfo?["reset"] as? Bool == true { completed = false }
                pageIndex = 0
                isPresented = !pages.isEmpty
            }
            .sheet(isPresented: $isPresented) {
                OnboardingSheet(
                    pages: pages,
                    index: $pageIndex,
                    finish: {
                        completed = true
                        isPresented = false
                    }
                )
                .interactiveDismissDisabled()
            }
    }
}

struct OnboardingSheet: View {
    let pages: [OnboardingPageItem]
    @Binding var index: Int
    let finish: () -> Void

    var body: some View {
        let safeIndex = min(max(index, 0), max(pages.count - 1, 0))
        VStack(spacing: 0) {
            HStack {
                Label("Getting started", systemImage: "graduationcap.fill")
                    .font(.headline)
                Spacer()
                Text("\(safeIndex + 1) of \(pages.count)").foregroundStyle(.secondary)
                Button("Skip") { finish() }.buttonStyle(.borderless)
            }
            .padding(20)
            Divider()
            if pages.indices.contains(safeIndex) {
                ScrollView { pages[safeIndex].makeView().padding(28) }
            }
            Divider()
            HStack {
                Button("Back") { index = max(0, safeIndex - 1) }
                    .disabled(safeIndex == 0)
                Spacer()
                Button(safeIndex == pages.count - 1 ? "Finish" : "Continue") {
                    if safeIndex == pages.count - 1 { finish() }
                    else { index = safeIndex + 1 }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(width: 640, height: 550)
    }
}
