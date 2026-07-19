import AppKit
import LumiKernel
import SwiftUI

public struct XcodeFileNotInTargetWarning: View {
    public let fileName: String
    public let onDismiss: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(LumiPluginLocalization.string("File Not Registered in Project", bundle: .module))
                    .font(.headline)
            }

            Text(
                String(
                    format: LumiPluginLocalization.string("\"%@\" is not bound to any compilation target. Cross-file semantic navigation may be unavailable.", bundle: .module),
                    fileName
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(LumiPluginLocalization.string("Got It", bundle: .module), action: onDismiss)
                    .buttonStyle(.bordered)

                Button(LumiPluginLocalization.string("Open in Xcode", bundle: .module)) {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: "")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    XcodeFileNotInTargetWarning(fileName: "MyFile.swift") { }
        .padding()
}
