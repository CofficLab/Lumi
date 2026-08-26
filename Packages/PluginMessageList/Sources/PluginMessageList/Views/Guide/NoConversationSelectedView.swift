import LumiUI
import ProviderProject
import ProviderPromptSuggestion
import SwiftUI
import UniformTypeIdentifiers

struct NoConversationSelectedView: View {
    @LumiTheme private var theme
    let services: MessageListServices
    @StateObject private var promptObserver: PromptSuggestionsObserver
    @StateObject private var projectObserver: ProjectObserver
    @State private var importingFolder = false
    @State private var projectError: String?

    init(services: MessageListServices) {
        self.services = services
        _promptObserver = StateObject(wrappedValue: PromptSuggestionsObserver(services: services))
        _projectObserver = StateObject(wrappedValue: ProjectObserver(project: services.project))
    }

    private var project: ProjectInfo? { projectObserver.project?.currentProject }
    private var suggestions: [PromptSuggestion] {
        visibleSuggestions(services.promptSuggestions?.allSuggestions ?? [], hasProject: project != nil)
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil").font(.system(size: 48, weight: .light)).foregroundColor(theme.textSecondary.opacity(0.5))
            if let project { projectTitle(project) } else {
                Text("How can I help you today?").font(.system(size: 18, weight: .semibold)).foregroundStyle(theme.textPrimary)
            }
            if !suggestions.isEmpty { PromptSuggestionFlow(suggestions: suggestions, services: services) { importingFolder = true } }
        }
        .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(isPresented: $importingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { @MainActor in do { try await services.project?.openProject(at: url.path) } catch { projectError = error.localizedDescription } }
        }
        .alert(LumiPluginLocalization.string("Failed to Open Project"), isPresented: Binding(get: { projectError != nil }, set: { if !$0 { projectError = nil } })) {
            Button(LumiPluginLocalization.string("OK"), role: .cancel) {}
        } message: { Text(projectError ?? "") }
    }

    @ViewBuilder
    private func projectTitle(_ project: ProjectInfo) -> some View {
        HStack(spacing: 0) {
            Text(LumiPluginLocalization.string("How can I help with "))
                .foregroundStyle(theme.textPrimary)
            Menu {
                ForEach(projectObserver.project?.projects ?? [], id: \.path) { item in
                    Button(item.name) { Task { @MainActor in do { try await services.project?.openProject(at: item.path) } catch { projectError = error.localizedDescription } } }
                }
                Divider()
                Button(LumiPluginLocalization.string("Add Project…")) { importingFolder = true }
            } label: {
                Text(project.name).foregroundStyle(theme.primary).lineLimit(1).truncationMode(.middle)
            }
            .menuStyle(.borderlessButton)
            .fixedSize(horizontal: true, vertical: false)
            Text(LumiPluginLocalization.string("?"))
                .foregroundStyle(theme.textPrimary)
        }.font(.system(size: 18, weight: .semibold))
    }
}
