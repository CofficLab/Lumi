import Foundation

/// 首次初始化 Projects 时，把 App 内的只读样本复制为用户可编辑的项目。
@MainActor
struct BundledSampleProjectInstaller {
    enum InstallerError: LocalizedError {
        case bundledProjectMissing(String)
        case bundledProjectIsNotDirectory(String)

        var errorDescription: String? {
            switch self {
            case let .bundledProjectMissing(path):
                return "Bundled sample project does not exist: \(path)"
            case let .bundledProjectIsNotDirectory(path):
                return "Bundled sample project is not a directory: \(path)"
            }
        }
    }

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// 安装样本并把它设为首个当前项目。
    ///
    /// `projects.json` 已存在时直接跳过，包括用户主动保存过空列表的情况。
    func installIfNeeded(from bundledProjectURL: URL, into store: ProjectsStore) throws {
        guard !store.hasPersistedProjects() else { return }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: bundledProjectURL.path, isDirectory: &isDirectory) else {
            throw InstallerError.bundledProjectMissing(bundledProjectURL.path)
        }
        guard isDirectory.boolValue else {
            throw InstallerError.bundledProjectIsNotDirectory(bundledProjectURL.path)
        }

        let samplesDirectory = store.pluginDirectory
            .appendingPathComponent("samples", isDirectory: true)
        let destinationURL = samplesDirectory
            .appendingPathComponent(bundledProjectURL.lastPathComponent, isDirectory: true)

        try fileManager.createDirectory(
            at: samplesDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // 如果上次启动在复制完成后、写入 projects.json 前中断，直接复用已复制目录。
        if !fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.copyItem(at: bundledProjectURL, to: destinationURL)
        }

        let project = ProjectEntry(
            name: bundledProjectURL.lastPathComponent,
            path: ProjectsStore.normalizedPath(destinationURL.path),
            language: ProjectLanguageDetector.detect(at: destinationURL.path)
        )
        store.save(projects: [project], currentProject: project)
    }
}
