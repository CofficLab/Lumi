import LumiUI
import ProviderPromptSuggestion
import SwiftUI
import UniformTypeIdentifiers

struct MessageEmptyStateView: View {
    @LumiTheme private var theme
    let services: MessageListServices
    @StateObject private var promptObserver: PromptSuggestionsObserver
    @State private var importingFolder = false
    @State private var projectError: String?

    init(services: MessageListServices) { self.services = services; _promptObserver = StateObject(wrappedValue: PromptSuggestionsObserver(services: services)) }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 48, weight: .light)).foregroundColor(theme.primary.opacity(0.75))
            Text(LumiPluginLocalization.string("Start chatting with Lumi"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
            Text(LumiPluginLocalization.string("Pick an example, or type your question below."))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
            let suggestions = visibleSuggestions(services.promptSuggestions?.allSuggestions ?? [], hasProject: services.project?.currentProject != nil)
            if !suggestions.isEmpty { PromptSuggestionFlow(suggestions: suggestions, services: services) { importingFolder = true }.padding(.top, 8) }
        }
        .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
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
