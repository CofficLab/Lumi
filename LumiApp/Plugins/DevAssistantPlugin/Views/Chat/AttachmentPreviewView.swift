import SwiftUI

/// 附件预览视图 - 显示待发送的图片缩略图
struct AttachmentPreviewView: View {
    let attachments: [AssistantViewModel.Attachment]
    let onRemove: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(attachments) { attachment in
                    if case let .image(_, data, _, _) = attachment,
                       let nsImage = NSImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                )

                            Button(action: {
                                onRemove(attachment.id)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                    .background(Color.white.clipShape(Circle()))
                            }
                            .buttonStyle(.plain)
                            .offset(x: 4, y: -4)
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
