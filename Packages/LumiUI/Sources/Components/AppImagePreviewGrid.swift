import SwiftUI

/// 位图解码缓存:图片字节不可变,历史上每次 body 求值(含消息列表滚动
/// 重物化)都重新执行 `NSImage(data:)` 全量位图解码。键为原始字节
/// (哈希远快于解码),LRU 有界。
enum AppImageDecodeCache {
    private static let limit = 128
    // 以下可变静态量均由 lock 保护，标记 nonisolated(unsafe) 以满足并发检查
    nonisolated(unsafe) private static var storage: [Data: LumiPlatformImage] = [:]
    nonisolated(unsafe) private static var insertionOrder: [Data] = []
    private static let lock = NSLock()

    static func image(for data: Data) -> LumiPlatformImage? {
        lock.lock()
        if let cached = storage[data] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let decoded = LumiPlatformImage(data: data) else { return nil }

        lock.lock()
        defer { lock.unlock() }
        if storage[data] == nil {
            insertionOrder.append(data)
        }
        storage[data] = decoded
        if insertionOrder.count > limit {
            let overflow = insertionOrder.count - limit
            for key in insertionOrder.prefix(overflow) {
                storage.removeValue(forKey: key)
            }
            insertionOrder.removeFirst(overflow)
        }
        return decoded
    }
}

public struct AppImagePreviewGrid: View {
    let imageDataList: [Data]
    @State private var previewingImage: LumiPlatformImage?

    public init(imageDataList: [Data]) {
        self.imageDataList = imageDataList
    }

    public var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 120, maximum: 220), spacing: 8, alignment: .leading),
            ],
            spacing: 8
        ) {
            ForEach(Array(imageDataList.enumerated()), id: \.offset) { _, data in
                if let nsImage = AppImageDecodeCache.image(for: data) {
                    Button {
                        previewingImage = nsImage
                    } label: {
                        Image(lumiImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 180, height: 120)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Click to preview image")
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { previewingImage != nil },
                set: { isPresented in
                    if !isPresented {
                        previewingImage = nil
                    }
                }
            )
        ) {
            if let previewingImage {
                AppImagePreviewSheet(image: previewingImage)
            }
        }
    }
}

private struct AppImagePreviewSheet: View {
    let image: LumiPlatformImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            GeometryReader { geometry in
                Image(lumiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                    .padding(20)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}

#Preview {
    AppImagePreviewGrid(imageDataList: [])
        .padding()
        .frame(width: 400, height: 300)
        .background(Color.gray.opacity(0.15))
}
