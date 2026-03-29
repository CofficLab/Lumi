import SwiftUI
import MagicKit

/// 附件预览视图 - 显示待发送的图片缩略图
struct AttachmentPreviewView: View {
    let attachments: [AgentPendingImageAttachment]
    let onRemove: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(attachments) { attachment in
                    if case let .image(_, data, _, _) = attachment,
                       let nsImage = NSImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            AppCard(
                                style: .subtle,
                                padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                            ) {
                                AppImageThumbnail(
                                    image: Image(nsImage: nsImage),
                                    size: CGSize(width: 60, height: 60),
                                    sizing: .fill,
                                    shape: .roundedMedium
                                )
                            }

                            AppIconButton(
                                systemImage: "xmark",
                                tint: DesignTokens.Color.semantic.textPrimary,
                                size: .compact
                            ) {
                                onRemove(attachment.id)
                            }
                            .background(
                                Circle()
                                    .fill(DesignTokens.Material.glass)
                            )
                            .clipShape(Circle())
                            .offset(x: 6, y: -6)
                        }
                        .padding(.top, 4)
                        .padding(.trailing, 4)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
}

#Preview {
    AttachmentPreviewView(
        attachments: [],
        onRemove: { _ in }
    )
    .frame(width: 400)
    .padding()
}
