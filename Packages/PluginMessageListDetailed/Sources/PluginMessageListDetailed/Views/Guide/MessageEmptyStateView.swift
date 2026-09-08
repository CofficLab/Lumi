import LumiUI
import ProviderChatSection
import ProviderPromptSuggestion
import SwiftUI
import UniformTypeIdentifiers

struct MessageEmptyStateView: View {
    @LumiTheme private var theme
    let services: MessageListServices
    @ObservedObject private var guideState: MessageListGuideState
    @State private var importingFolder = false
    @State private var projectError: String?

    init(services: MessageListServices, guideState: MessageListGuideState) {
        self.services = services
        _guideState = ObservedObject(wrappedValue: guideState)
    }

    private var emptyStateTitle: String {
        let context = guideState.context
        if context?.id == ChatContext.defaultChat.id {
            return LumiPluginLocalization.string("Start chatting with Lumi")
        }
        if let title = context?.title {
            return String(format: LumiPluginLocalization.string("For 「%@」, what can I help you with?"), title)
        }
        return LumiPluginLocalization.string("Start chatting with Lumi")
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                EmptyStateAtmosphere()

                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        EmptyStateHeroIcon(systemImage: guideState.context?.systemImage ?? "bubble.left.and.bubble.right")
                            .padding(.bottom, 18)

                        Text(emptyStateTitle)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)
                            .multilineTextAlignment(.center)

                        if let subtitle = guideState.context?.subtitle,
                           guideState.context?.id != ChatContext.defaultChat.id {
                            Text(subtitle)
                                .font(.system(size: 13))
                                .foregroundStyle(theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                        } else {
                            Text(LumiPluginLocalization.string("Pick an example, or type your question below."))
                                .font(.system(size: 13))
                                .foregroundStyle(theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                        }

                        let suggestions = visibleSuggestions(
                            services.promptSuggestions?.allSuggestions ?? [],
                            hasProject: services.project?.currentProject != nil,
                            contextID: guideState.context?.id
                        )
                        if !suggestions.isEmpty {
                            PromptSuggestionFlow(suggestions: suggestions, services: services) { importingFolder = true }
                                .padding(.top, 24)
                        }
                    }
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity, minHeight: max(320, proxy.size.height - 24))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 36)
                    .offset(y: -min(24, proxy.size.height * 0.06))
                }
                .scrollIndicators(.hidden)
            }
        }
        .fileImporter(isPresented: $importingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { @MainActor in
                do { try await services.project?.openProject(at: url.path) }
                catch { projectError = error.localizedDescription }
            }
        }
        .alert(LumiPluginLocalization.string("Failed to Open Project"), isPresented: Binding(get: { projectError != nil }, set: { if !$0 { projectError = nil } })) {
            Button(LumiPluginLocalization.string("OK"), role: .cancel) {}
        } message: { Text(projectError ?? "") }
    }
}
