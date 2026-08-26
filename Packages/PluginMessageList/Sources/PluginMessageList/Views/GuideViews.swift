import Combine
import LumiUI
import ProviderMessageSender
import ProviderPluginControl
import ProviderPluginManaging
import ProviderPromptSuggestion
import ProviderProject
import ProviderToast
import ProviderWorkspace
import SwiftUI
import UniformTypeIdentifiers

struct MessageLoadingView: View {
    @LumiTheme private var theme
    @State private var breathing = false
    var body: some View {
        Image(systemName: "bubble.left.and.bubble.right").font(.largeTitle)
            .foregroundStyle(theme.textSecondary).opacity(breathing ? 0.3 : 1)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: breathing)
            .onAppear { breathing = true }
            .accessibilityLabel(Text(LumiPluginLocalization.string("Loading messages…")))
    }
}

@MainActor
private func handlePromptTap(_ suggestion: PromptSuggestion, services: MessageListServices,
                             pickFolder: (() -> Void)? = nil) {
    switch suggestion.action {
    case .pickProjectFolder:
        pickFolder?(); return
    case .openSettingsTab:
        NotificationCenter.default.post(name: Notification.Name("lumi.openSettings"), object: nil); return
    case nil, .activateViewContainer, .activateRailTab:
        break
    }
    Task { @MainActor in
        if suggestion.requiresEnable, let pluginID = suggestion.pluginID,
           let control = services.pluginControl, await control.enablePlugin(id: pluginID) {
            let name = services.pluginManager?.plugin(id: pluginID)?.metadata.name ?? pluginID
            services.toast?.show("Plugin Enabled", detail: "\(name) is now enabled.", style: .success)
        }
        switch suggestion.action {
        case .activateViewContainer(let id): services.workspace?.activateContainer(id: id)
        case .activateRailTab(let id, let containerID):
            services.workspace?.activateContainer(id: containerID)
            services.workspace?.presentRailTab(id: id, for: containerID)
        default: break
        }
        try? await services.sender?.sendMessage(suggestion.prompt, conversationID: nil)
    }
}

private struct PromptSuggestionChip: View {
    @LumiTheme private var theme
    @LumiMotionPreferenceReader private var motionPreference
    let suggestion: PromptSuggestion
    @State private var hovered = false
    var body: some View {
        HStack(spacing: 6) {
            if let image = suggestion.systemImage { Image(systemName: image).font(.system(size: 12, weight: .medium)) }
            Text(suggestion.title).font(.appCaption).lineLimit(1)
        }
        .foregroundStyle(suggestion.style == .additive ? theme.textSecondary : theme.textPrimary)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(suggestion.style == .additive ? .clear : theme.primary.opacity(hovered ? 0.22 : 0.12)))
        .overlay { Capsule().strokeBorder(hovered ? theme.primary.opacity(0.4) : theme.primary.opacity(suggestion.style == .additive ? 0.35 : 0.22), style: StrokeStyle(lineWidth: 1, dash: suggestion.style == .additive ? [4, 3] : [])) }
        .scaleEffect(hovered && motionPreference.allowsMotion ? LumiMotion.hoverScale : 1)
        .animation(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference), value: hovered)
        .onHover { value in LumiMotion.animate(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)) { hovered = value } }
    }
}

private struct PromptSuggestionFlow: View {
    let suggestions: [PromptSuggestion]
    let services: MessageListServices
    let pickFolder: (() -> Void)?
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                Button { handlePromptTap(suggestion, services: services, pickFolder: pickFolder) } label: { PromptSuggestionChip(suggestion: suggestion) }
                    .buttonStyle(.plain).landingAppear(delay: Double(index) * 0.04)
            }
        }.frame(maxWidth: 520)
    }
}

@MainActor
private func visibleSuggestions(_ all: [PromptSuggestion], hasProject: Bool) -> [PromptSuggestion] {
    all.filter {
        switch $0.visibility { case .always: true; case .onlyWithProject: hasProject; case .onlyWithoutProject: !hasProject }
    }
}

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
    private var suggestions: [PromptSuggestion] { visibleSuggestions(services.promptSuggestions?.allSuggestions ?? [], hasProject: project != nil) }
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil").font(.system(size: 48, weight: .light)).foregroundColor(theme.textSecondary.opacity(0.5))
            if let project { projectTitle(project) } else { Text("How can I help you today?").font(.system(size: 18, weight: .semibold)).foregroundStyle(theme.textPrimary) }
            if !suggestions.isEmpty { PromptSuggestionFlow(suggestions: suggestions, services: services) { importingFolder = true } }
        }
        .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(isPresented: $importingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { @MainActor in do { try await services.project?.openProject(at: url.path) } catch { projectError = error.localizedDescription } }
        }
        .alert("Failed to Open Project", isPresented: Binding(get: { projectError != nil }, set: { if !$0 { projectError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(projectError ?? "") }
    }
    @ViewBuilder private func projectTitle(_ project: ProjectInfo) -> some View {
        HStack(spacing: 0) {
            Text("How can I help with ").foregroundStyle(theme.textPrimary)
            Menu {
                ForEach(projectObserver.project?.projects ?? [], id: \.path) { item in
                    Button(item.name) { Task { @MainActor in do { try await services.project?.openProject(at: item.path) } catch { projectError = error.localizedDescription } } }
                }
                Divider(); Button("Add Project…") { importingFolder = true }
            } label: { Text(project.name).foregroundStyle(theme.primary) }.menuStyle(.borderlessButton)
            Text("?").foregroundStyle(theme.textPrimary)
        }.font(.system(size: 18, weight: .semibold))
    }
}

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
            Text("Start chatting with Lumi").font(.system(size: 18, weight: .semibold)).foregroundStyle(theme.textPrimary)
            Text("Pick an example, or type your question below.").foregroundStyle(theme.textSecondary).multilineTextAlignment(.center)
            let suggestions = visibleSuggestions(
                services.promptSuggestions?.allSuggestions ?? [],
                hasProject: services.project?.currentProject != nil
            )
            if !suggestions.isEmpty {
                PromptSuggestionFlow(suggestions: suggestions, services: services) { importingFolder = true }.padding(.top, 8)
            }
        }
        .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(isPresented: $importingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { @MainActor in
                do { try await services.project?.openProject(at: url.path) }
                catch { projectError = error.localizedDescription }
            }
        }
        .alert("Failed to Open Project", isPresented: Binding(get: { projectError != nil }, set: { if !$0 { projectError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(projectError ?? "") }
    }
}

@MainActor private final class PromptSuggestionsObserver: ObservableObject {
    private var cancellable: AnyCancellable?
    init(services: MessageListServices) { cancellable = services.promptSuggestionsChangesPublisher.sink { [weak self] _ in self?.objectWillChange.send() } }
}
@MainActor private final class ProjectObserver: ObservableObject {
    let project: (any ProjectProviding)?
    private var cancellable: AnyCancellable?
    init(project: (any ProjectProviding)?) { self.project = project; cancellable = project?.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() } }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .greatestFiniteMagnitude; var x: CGFloat = 0; var y: CGFloat = 0; var row: CGFloat = 0
        for view in subviews { let size = view.sizeThatFits(.unspecified); if x > 0 && x + spacing + size.width > width { y += row + spacing; x = 0; row = 0 }; x += (x == 0 ? 0 : spacing) + size.width; row = max(row, size.height) }
        return CGSize(width: min(x, width), height: y + row)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var row: CGFloat = 0
        for view in subviews { let size = view.sizeThatFits(.unspecified); if x > bounds.minX && x + size.width > bounds.maxX { x = bounds.minX; y += row + spacing; row = 0 }; view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size)); x += size.width + spacing; row = max(row, size.height) }
    }
}
