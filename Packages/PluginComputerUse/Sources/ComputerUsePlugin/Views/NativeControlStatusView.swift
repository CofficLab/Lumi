import SwiftUI

struct NativeControlStatusView: View {
    @ObservedObject var state: NativeControlCoordinator

    private var title: String {
        switch state.phase {
        case .permission: computerUseText("Allow Lumi to operate your computer?")
        case .preparing: computerUseText("Preparing to operate {app}", ["app": state.applicationName])
        case .running: computerUseText("Lumi is operating {app}", ["app": state.applicationName])
        case .paused: computerUseText("Computer operation paused")
        case .idle: computerUseText("Computer operation finished")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: state.phase == .paused ? "pause.circle.fill" : "cursorarrow.motionlines")
                .font(.headline)
            if !state.reason.isEmpty { Text(state.reason).font(.callout).lineLimit(3) }
            Text(detail).font(.caption).foregroundStyle(.secondary)
            HStack {
                if state.phase == .permission {
                    Button(computerUseText("Allow and Continue")) { state.allow() }.buttonStyle(.borderedProminent)
                } else if state.phase == .paused {
                    Button(computerUseText("Continue Operation")) { state.resume() }.buttonStyle(.borderedProminent)
                }
                Spacer()
                Button(computerUseText(state.phase == .permission ? "Not Now" : "Stop Operation")) { state.stop() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("computer-use.stop")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var detail: String {
        switch state.phase {
        case .permission:
            computerUseText("This step uses your mouse and keyboard. Permission is remembered for this app. You can stop at any time.")
        case .preparing, .running:
            computerUseText("{progress} · Please pause mouse and keyboard use. Your input pauses Lumi. Press ⌘⇧Esc to stop.", ["progress": state.progress])
        case .paused:
            computerUseText("You can use your computer. Continuing checks the screen again without replaying earlier clicks.")
        case .idle: computerUseText("You can use your computer.")
        }
    }
}
