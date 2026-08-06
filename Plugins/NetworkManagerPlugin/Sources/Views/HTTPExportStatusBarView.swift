import LumiUI
import SwiftUI

/// Status bar indicator shown while a batch HTTP log export is running.
///
/// Rendered as an empty view when idle, so it only occupies space (and draws
/// the user's attention) during an actual export.
public struct HTTPExportStatusBarView: View {
    @ObservedObject private var progress = HTTPExportProgress.shared

    public init() {}

    public var body: some View {
        if progress.isExporting {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(progress.statusText)
                    .font(.appCaption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)
        } else {
            EmptyView()
        }
    }
}
