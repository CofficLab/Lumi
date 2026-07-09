import Foundation
import os
import SuperLogKit

/// xcassets 目录解析器
///
/// 解析 xcassets 目录结构，提取颜色集和图片集信息。
public enum XCAssetsParser: SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview.xcassets-parser"
    )
    public nonisolated static let emoji = "🎨"
    public nonisolated static let verbose: Bool = true

    /// 解析结果
    public enum ParseResult {
        case success(XCAssetsContent)
        case failure(Error)
    }

    /// xcassets 内容
    public struct XCAssetsContent {
        public let colors: [ColorSet]
        public let images: [ImageSet]

        public var isEmpty: Bool {
            colors.isEmpty && images.isEmpty
        }

        public var totalItemCount: Int {
            colors.count + images.count
        }
    }

    /// 颜色集
    public struct ColorSet: Identifiable {
        public let id = UUID()
        public let name: String
        public let directoryURL: URL
        public let lightColor: RGBAColor
        public let darkColor: RGBAColor?

        public var displayName: String {
            // 移除 .colorset 后缀
            (name as NSString).deletingPathExtension
        }
    }

    /// 图片集
    public struct ImageSet: Identifiable {
        public let id = UUID()
        public let name: String
        public let directoryURL: URL
        public let type: ImageSetType
        public let imageFiles: [ImageFile]

        public var displayName: String {
            // 移除 .imageset 或 .appiconset 后缀
            (name as NSString).deletingPathExtension
        }

        /// 获取最佳预览图片（优先选择 1x 或 universal）
        public var previewImageFile: ImageFile? {
            // 优先选择 universal
            if let universal = imageFiles.first(where: { $0.idiom == "universal" }) {
                return universal
            }
            // 其次选择 1x
            if let oneX = imageFiles.first(where: { $0.scale == "1x" }) {
                return oneX
            }
            // 否则返回第一个
            return imageFiles.first
        }
    }

    /// 图片集类型
    public enum ImageSetType {
        case appIcon
        case image
    }

    /// 图片文件信息
    public struct ImageFile {
        public let fileName: String
        public let fileURL: URL
        public let idiom: String
        public let scale: String?
        public let size: String?
    }

    /// RGBA 颜色
    public struct RGBAColor: Sendable {
        public let red: Double
        public let green: Double
        public let blue: Double
        public let alpha: Double

        public static let white = RGBAColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        public static let clear = RGBAColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    }

    /// 解析 xcassets 目录
    public static func parse(xcassetsURL: URL) -> ParseResult {
        do {
            let fileManager = FileManager.default
            var colors: [ColorSet] = []
            var images: [ImageSet] = []

            // 遍历 xcassets 目录下的所有子目录
            let contents = try fileManager.contentsOfDirectory(
                at: xcassetsURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for itemURL in contents {
                let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
                guard resourceValues.isDirectory == true else { continue }

                let pathExtension = itemURL.pathExtension.lowercased()

                switch pathExtension {
                case "colorset":
                    if let colorSet = try parseColorSet(at: itemURL) {
                        colors.append(colorSet)
                    }

                case "imageset":
                    if let imageSet = try parseImageSet(at: itemURL, type: .image) {
                        images.append(imageSet)
                    }

                case "appiconset":
                    if let imageSet = try parseImageSet(at: itemURL, type: .appIcon) {
                        images.append(imageSet)
                    }

                default:
                    // 忽略其他类型的目录（如 .brandassets 等）
                    break
                }
            }

            // 按名称排序
            colors.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            images.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            let content = XCAssetsContent(colors: colors, images: images)
            return .success(content)

        } catch {
            return .failure(error)
        }
    }

    /// 解析颜色集
    private static func parseColorSet(at directoryURL: URL) throws -> ColorSet? {
        let contentsJSONURL = directoryURL.appendingPathComponent("Contents.json")
        guard FileManager.default.fileExists(atPath: contentsJSONURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: contentsJSONURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let colorsArray = json["colors"] as? [[String: Any]] else {
            return nil
        }

        var lightColor: RGBAColor?
        var darkColor: RGBAColor?

        // 遍历所有颜色定义
        for colorEntry in colorsArray {
            guard let colorDict = colorEntry["color"] as? [String: Any] else { continue }

            // 提取 RGB 值
            if let components = colorDict["components"] as? [String: Any] {
                let red = Double(components["red"] as? String ?? "1.0") ?? 1.0
                let green = Double(components["green"] as? String ?? "1.0") ?? 1.0
                let blue = Double(components["blue"] as? String ?? "1.0") ?? 1.0
                let alpha = Double(components["alpha"] as? String ?? "1.0") ?? 1.0

                let color = RGBAColor(red: red, green: green, blue: blue, alpha: alpha)

                // 判断是 light 还是 dark 模式
                if let appearances = colorEntry["appearances"] as? [[String: Any]] {
                    // 有 appearances，检查是否是 dark mode
                    let isDark = appearances.contains { appearance in
                        appearance["appearance"] as? String == "luminosity" &&
                        appearance["value"] as? String == "dark"
                    }
                    if isDark {
                        darkColor = color
                    }
                } else {
                    // 没有 appearances，这是默认（light）颜色
                    lightColor = color
                }
            }
        }

        guard let light = lightColor else { return nil }

        return ColorSet(
            name: directoryURL.lastPathComponent,
            directoryURL: directoryURL,
            lightColor: light,
            darkColor: darkColor
        )
    }

    /// 解析图片集
    private static func parseImageSet(at directoryURL: URL, type: ImageSetType) throws -> ImageSet? {
        let contentsJSONURL = directoryURL.appendingPathComponent("Contents.json")
        guard FileManager.default.fileExists(atPath: contentsJSONURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: contentsJSONURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var imageFiles: [ImageFile] = []

        // 根据类型解析不同的键
        let imagesKey = type == .appIcon ? "images" : "images"
        guard let imagesArray = json[imagesKey] as? [[String: Any]] else {
            return ImageSet(
                name: directoryURL.lastPathComponent,
                directoryURL: directoryURL,
                type: type,
                imageFiles: []
            )
        }

        // 遍历所有图片定义
        for imageEntry in imagesArray {
            guard let fileName = imageEntry["filename"] as? String else { continue }

            let fileURL = directoryURL.appendingPathComponent(fileName)

            // 只添加实际存在的文件
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }

            let idiom = imageEntry["idiom"] as? String ?? "universal"
            let scale = imageEntry["scale"] as? String
            let size = imageEntry["size"] as? String

            let imageFile = ImageFile(
                fileName: fileName,
                fileURL: fileURL,
                idiom: idiom,
                scale: scale,
                size: size
            )
            imageFiles.append(imageFile)
        }

        return ImageSet(
            name: directoryURL.lastPathComponent,
            directoryURL: directoryURL,
            type: type,
            imageFiles: imageFiles
        )
    }
}
