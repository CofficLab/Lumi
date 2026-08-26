import LumiUI
import ProviderMessageSender
import ProviderPluginControl
import ProviderPluginManaging
import ProviderPromptSuggestion
import ProviderToast
import ProviderWorkspace
import SwiftUI

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

struct PromptSuggestionFlow: View {
    let suggestions: [PromptSuggestion]
    let services: MessageListServices
    let pickFolder: (() -> Void)?

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                Button { handlePromptTap(suggestion, services: services, pickFolder: pickFolder) } label: {
                    PromptSuggestionChip(suggestion: suggestion)
                }
                .buttonStyle(.plain)
                .landingAppear(delay: Double(index) * 0.04)
            }
        }
        .frame(maxWidth: 520)
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

@MainActor
func visibleSuggestions(_ all: [PromptSuggestion], hasProject: Bool) -> [PromptSuggestion] {
    all.filter {
        switch $0.visibility { case .always: true; case .onlyWithProject: hasProject; case .onlyWithoutProject: !hasProject }
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0; var y: CGFloat = 0; var row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + spacing + size.width > width { y += row + spacing; x = 0; row = 0 }
            x += (x == 0 ? 0 : spacing) + size.width; row = max(row, size.height)
        }
        return CGSize(width: min(x, width), height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX { x = bounds.minX; y += row + spacing; row = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; row = max(row, size.height)
        }
    }
}
