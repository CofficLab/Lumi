import SwiftUI

/// 图片文件预览视图
///
/// 使用 QuickLook 预览图片，同时根据图片原始尺寸进行适当缩放。
/// 小图片不会被过度拉伸，大图片会被限制在视图范围内。
struct ImageFilePreviewView: View {

    private let imageURL: URL

    init(_ imageURL: URL) {
        self.imageURL = imageURL
    }

    var body: some View {
        if let nsImage = NSImage(contentsOf: imageURL),
           let imageRep = nsImage.representations.first {

            let pixelWidth = CGFloat(imageRep.pixelsWide)
            let pixelHeight = CGFloat(imageRep.pixelsHigh)

            GeometryReader { proxy in
                ZStack {
                    AnyFilePreviewView(imageURL)
                        .frame(
                            maxWidth: min(pixelWidth, proxy.size.width, nsImage.size.width),
                            maxHeight: min(pixelHeight, proxy.size.height, nsImage.size.height)
                        )
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        } else {
            unsupportedPreviewView
        }
    }

    private var unsupportedPreviewView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo")
                .font(.system(size: 36, weight: .thin))
                .foregroundColor(AppUI.Color.semantic.textTertiary)

            Text(String(localized: "Cannot preview image", table: "LumiEditor"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
