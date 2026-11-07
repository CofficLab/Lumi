import Clibgit2
import Foundation

extension LibGit2 {
    /// 列出仓库级别的所有配置项。
    public static func listConfig(at path: String) throws -> [(key: String, value: String)] {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var config: OpaquePointer?
            defer { if config != nil { git_config_free(config) } }

            guard git_repository_config(&config, repo) == 0, let config else {
                throw LibGit2Error.configNotFound
            }

            return listConfigEntries(config)
        }
    }

    /// 列出全局配置的所有配置项。
    public static func listGlobalConfig() throws -> [(key: String, value: String)] {
        return try LibGit2.serialized {
            var config: OpaquePointer?
            defer { if config != nil { git_config_free(config) } }

            guard git_config_open_default(&config) == 0, let config else {
                throw LibGit2Error.configNotFound
            }

            return listConfigEntries(config)
        }
    }

    // MARK: - Private

    private static func listConfigEntries(_ config: OpaquePointer) -> [(key: String, value: String)] {
        var iterator: UnsafeMutablePointer<git_config_iterator>?
        defer { if iterator != nil { git_config_iterator_free(iterator) } }

        guard git_config_iterator_new(&iterator, config) == 0, let iter = iterator else {
            return []
        }

        var entries: [(key: String, value: String)] = []
        var entry: UnsafeMutablePointer<git_config_entry>?

        while git_config_next(&entry, iter) == 0, let e = entry {
            let key = e.pointee.name.map { String(cString: $0) } ?? ""
            let value = e.pointee.value.map { String(cString: $0) } ?? ""
            entries.append((key: key, value: value))
        }

        return entries.sorted { $0.key < $1.key }
    }
}
