import LumiCoreMessage
import LumiUI
import SwiftUI

struct ChatAttachmentPreviewView: View {
    @LumiTheme private var theme

    let attachments: [LumiImageAttachment]
    let onRemove: (UUID) -> Void

    var body: some View {
        if !attachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(attachments) { attachment in
                        ZStack(alignment: .topTrailing) {
                            if let data = Data(base64Encoded: attachment.base64Data),
                               let image = NSImage(data: data) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }

                            Button {
                                onRemove(attachment.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, .black.opacity(0.55))
                            }
                            .buttonStyle(.plain)
                            .offset(x: 6, y: -6)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(theme.textPrimary.opacity(0.04))
        }
    }
}
