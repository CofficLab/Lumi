import SwiftUI
import LumiKernel

public struct EditorLoadFailureView: View {
    public let fileName: String
    public let message: String

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .thin))
                .foregroundColor(Color(hex: "98989E"))

            Text(LumiPluginLocalization.string("Unable to Open File", bundle: .module))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            if !fileName.isEmpty {
                Text(fileName)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "98989E"))
            }

            Text(message)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "98989E"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
