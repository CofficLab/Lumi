import LumiUI
import ProviderToolManager
import SwiftUI

struct ToolJobOutputPopover: View {
    let job: ToolJob

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                Text("工具输出")
                    .font(.appCaptionEmphasized)
                Spacer()
                Text(job.toolCall.name)
                    .font(.appMicro)
                    .foregroundColor(.secondary)
            }

            if job.latestOutput.isEmpty {
                AppLoadingOverlay(message: "暂时没有输出", size: .small)
                    .frame(height: 60)
            } else {
                ScrollView(.vertical) {
                    Text(job.latestOutput)
                        .font(.appMonoCaption)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 80, maxHeight: 260)
            }
        }
        .padding(12)
        .frame(width: 360)
        .appSurface(style: .popover, cornerRadius: 12)
    }
}
