import Foundation
import LibGit2Swift

/// Git Submodule 服务（基于 LibGit2 原生 API）。
public enum GitSubmoduleService {

    public static func list(at path: String) -> [GitSubmoduleInfo] {
        (try? LibGit2.submodules(at: path)) ?? []
    }

    public static func hasSubmodules(at path: String) -> Bool {
        !list(at: path).isEmpty
    }

    public static func initialize(paths: [String] = [], at path: String, recursive: Bool = true) throws {
        try LibGit2.initializeSubmodules(
            paths: paths,
            at: path,
            recursive: recursive,
            verbose: false
        )
    }

    public static func update(
        paths: [String] = [],
        at path: String,
        initialize: Bool = false,
        recursive: Bool = true
    ) throws {
        try LibGit2.updateSubmodules(
            paths: paths,
            at: path,
            initialize: initialize,
            recursive: recursive,
            verbose: false
        )
    }

    public static func diff(path submodulePath: String, at path: String) -> String {
        (try? LibGit2.submoduleDiff(path: submodulePath, at: path)) ?? ""
    }
}
