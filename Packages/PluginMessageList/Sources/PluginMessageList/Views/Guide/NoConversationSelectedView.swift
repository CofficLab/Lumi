import LumiUI
import ProviderChatSection
import ProviderProject
import ProviderPromptSuggestion
import SwiftUI
import UniformTypeIdentifiers

struct NoConversationSelectedView: View {
    @LumiTheme private var theme
    let services: MessageListServices
    @StateObject private var promptObserver: PromptSuggestionsObserver
    @StateObject private var contextObserver: ChatContextObserver
    @StateObject private var projectObserver: ProjectObserver
    @StateObject private var toolbarCoordinator: NoConversationSelectedToolbarCoordinator
    @State private var importingFolder = false
    @State private var projectError: String?

    init(services: MessageListServices) {
        self.services = services
        _promptObserver = StateObject(wrappedValue: PromptSuggestionsObserver(services: services))
        _contextObserver = StateObject(wrappedValue: ChatContextObserver(chat: services.chat))
        _projectObserver = StateObject(wrappedValue: ProjectObserver(project: services.project))
        _toolbarCoordinator = StateObject(wrappedValue: NoConversationSelectedToolbarCoordinator(
            project: services.project,
            toolbar: services.toolbar
        ))
    }

    private var project: ProjectInfo? { projectObserver.project?.currentProject }
    private var suggestions: [PromptSuggestion] {
        visibleSuggestions(
            services.promptSuggestions?.allSuggestions ?? [],
            hasProject: project != nil,
            contextID: contextObserver.context?.id
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                EmptyStateAtmosphere()

                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        EmptyStateHeroIcon(systemImage: contextObserver.context?.systemImage ?? "square.and.pencil")
                            .padding(.bottom, 18)

                        if let context = contextObserver.context,
                           context.id != ChatContext.defaultChat.id {
                            Text("对于 「\(context.title)」，我可以帮你做什么")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(theme.textPrimary)
                                .multilineTextAlignment(.center)
                            if let subtitle = context.subtitle {
                                Text(subtitle)
                                    .font(.system(size: 13))
                                    .foregroundStyle(theme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 8)
                            }
                        } else if let project {
                            projectTitle(project)
                        } else {
                            Text(LumiPluginLocalization.string("How can I help you today?"))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(theme.textPrimary)
                                .multilineTextAlignment(.center)
                        }

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
        .onAppear {
            toolbarCoordinator.activate()
        }
        .onDisappear {
            toolbarCoordinator.deactivate()
        }
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
            Text(LumiPluginLocalization.string("对于 「"))
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
            Text(LumiPluginLocalization.string("」，我可以帮你做什么"))
                .foregroundStyle(theme.textPrimary)
        }.font(.system(size: 18, weight: .semibold))
    }
}
