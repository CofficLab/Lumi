import Foundation

/// Exports an Icon Composer document that Xcode 26 can compile for both the
/// current icon system and legacy deployment targets.
public struct IconComposerExportService {
    public struct ExportResult: Sendable, Equatable {
        public let iconURL: URL

        public init(iconURL: URL) {
            self.iconURL = iconURL
        }
    }

    private struct Manifest: Encodable {
        struct Group: Encodable {
            struct Layer: Encodable {
                let imageName: String
                let name: String

                enum CodingKeys: String, CodingKey {
                    case imageName = "image-name"
                    case name
                }
            }

            let layers: [Layer]
            let name: String
            let shadow: Shadow
            let specular: Bool
            let translucency: Translucency
        }

        struct Shadow: Encodable {
            let kind = "neutral"
            let opacity = 0.5
        }

        struct Translucency: Encodable {
            let enabled = false
            let value = 0.5
        }

        struct SupportedPlatforms: Encodable {
            let squares = ["macOS"]
        }

        let groups: [Group]
        let supportedPlatforms = SupportedPlatforms()

        enum CodingKeys: String, CodingKey {
            case groups
            case supportedPlatforms = "supported-platforms"
        }
    }

    private let fileManager: FileManager
    private let appIconExportService: AppIconExportService

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.appIconExportService = AppIconExportService(fileManager: fileManager)
    }

    @MainActor
    public func export(
        document: IconDocument,
        outputDirectory: URL,
        name: String = "AppIcon"
    ) async throws -> ExportResult {
        let document = IconDocumentSanitizer.sanitized(document)
        nonisolated(unsafe) let fileManager = self.fileManager

        // lint 是纯校验，放到后台先跑，blocked 文档直接失败、不浪费栅格化。
        try await Task.detached(priority: .userInitiated) {
            let lintReport = IconDocumentLinter().lint(document)
            if !lintReport.isExportable {
                throw IconDocumentLintError.blocked(lintReport.errors)
            }
        }.value

        // ImageRenderer 只能在主 actor 栅格化；其余 PNG 压缩、manifest 编码与
        // 全部原子文件写入都移到后台，避免整条导出管线阻塞 UI（见 issue #1291）。
        let cgImage = try appIconExportService.renderPreviewCGImage(document: document, pixelSize: 1024)
        return try await Task.detached(priority: .userInitiated) {
            let artwork = try AppIconExportService.encodePNG(cgImage: cgImage)
            return try Self.writeIconSet(
                artwork: artwork,
                outputDirectory: outputDirectory,
                name: name,
                fileManager: fileManager
            )
        }.value
    }

    public func export(
        sourceImagePath: String,
        outputDirectory: URL,
        name: String = "AppIcon"
    ) throws -> ExportResult {
        let artwork = try appIconExportService.renderSourcePNG(sourceImagePath: sourceImagePath, pixelSize: 1024)
        return try export(artwork: artwork, outputDirectory: outputDirectory, name: name)
    }

    private func export(artwork: Data, outputDirectory: URL, name: String) throws -> ExportResult {
        try Self.writeIconSet(
            artwork: artwork,
            outputDirectory: outputDirectory,
            name: name,
            fileManager: fileManager
        )
    }

    /// 把 artwork 写成 Xcode `.icon` 集：建目录、原子写 PNG、编码并写 manifest、
    /// replace/move 安装。纯文件 IO 与编码，无 actor 亲和，可在后台执行（见 issue #1291）。
    nonisolated private static func writeIconSet(
        artwork: Data,
        outputDirectory: URL,
        name: String,
        fileManager: FileManager
    ) throws -> ExportResult {
        let safeName = Self.safeName(name)
        let iconURL = outputDirectory.appendingPathComponent("\(safeName).icon", isDirectory: true)
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let temporaryURL = outputDirectory.appendingPathComponent(
            ".\(safeName).icon.\(UUID().uuidString).tmp",
            isDirectory: true
        )
        let assetsURL = temporaryURL.appendingPathComponent("Assets", isDirectory: true)
        try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)

        var installed = false
        defer {
            if !installed {
                try? fileManager.removeItem(at: temporaryURL)
            }
        }

        let artworkName = "Artwork.png"
        try artwork.write(to: assetsURL.appendingPathComponent(artworkName), options: .atomic)

        let manifest = Manifest(
            groups: [
                Manifest.Group(
                    layers: [.init(imageName: artworkName, name: "Artwork")],
                    name: "Artwork",
                    shadow: .init(),
                    specular: false,
                    translucency: .init()
                )
            ]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(
            to: temporaryURL.appendingPathComponent("icon.json"),
            options: .atomic
        )

        if fileManager.fileExists(atPath: iconURL.path) {
            _ = try fileManager.replaceItemAt(iconURL, withItemAt: temporaryURL)
        } else {
            try fileManager.moveItem(at: temporaryURL, to: iconURL)
        }
        installed = true
        return ExportResult(iconURL: iconURL)
    }

    private static func safeName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let safe = name.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return safe.isEmpty ? "AppIcon" : safe
    }
}
