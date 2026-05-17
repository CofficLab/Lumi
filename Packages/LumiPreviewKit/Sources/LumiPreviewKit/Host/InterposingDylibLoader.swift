import Darwin
import Foundation

public extension LumiPreviewFacade {
    /// 动态库加载器，支持 dlopen/dlsym 和 interpose 机制。
    ///
    /// 管理通过 `dlopen` 加载的动态库句柄，提供符号查找和批量卸载能力。
    /// 主要用于加载预览入口 dylib 并通过 interpose 实现热更新。
    actor InterposingDylibLoader {
        /// 已加载的 dylib 描述。
        public struct LoadedImage: Sendable, Equatable {
            /// dylib 文件路径。
            public let path: String
            /// 查找的符号名（可选）。
            public let symbolName: String?

            public init(path: String, symbolName: String?) {
                self.path = path
                self.symbolName = symbolName
            }
        }

        /// 加载器错误类型。
        public enum LoaderError: Error, Equatable, LocalizedError {
            /// dylib 文件不存在。
            case missingDylib(path: String)
            /// dlopen 调用失败。
            case dlopenFailed(message: String)
            /// 指定符号未找到。
            case symbolNotFound(symbolName: String)

            public var errorDescription: String? {
                switch self {
                case .missingDylib(let path):
                    return "Dylib does not exist: \(path)"
                case .dlopenFailed(let message):
                    return message
                case .symbolNotFound(let symbolName):
                    return "Symbol not found: \(symbolName)"
                }
            }
        }

        private var handlesByPath: [String: UnsafeMutableRawPointer] = [:]

        public init() {}

        /// 加载指定 dylib 并可选地验证符号存在。
        ///
        /// - Parameters:
        ///   - dylibPath: dylib 文件路径。
        ///   - symbolName: 需要验证的符号名（可选）。
        ///   - mode: dlopen 标志，默认 `RTLD_NOW | RTLD_LOCAL`。
        /// - Returns: 加载结果描述。
        public func load(
            dylibPath: String,
            symbolName: String? = nil,
            mode: Int32 = RTLD_NOW | RTLD_LOCAL
        ) throws -> LoadedImage {
            guard FileManager.default.fileExists(atPath: dylibPath) else {
                throw LoaderError.missingDylib(path: dylibPath)
            }

            let handle = try openHandle(dylibPath: dylibPath, mode: mode)
            if let symbolName {
                guard dlsym(handle, symbolName) != nil else {
                    throw LoaderError.symbolNotFound(symbolName: symbolName)
                }
            }

            return LoadedImage(path: dylibPath, symbolName: symbolName)
        }

        /// 在指定 dylib 中查找符号是否存在。
        ///
        /// - Parameters:
        ///   - symbolName: 符号名。
        ///   - dylibPath: dylib 文件路径。
        /// - Returns: 符号是否存在。
        public func resolveSymbol(
            named symbolName: String,
            in dylibPath: String
        ) throws -> Bool {
            let handle = try openHandle(dylibPath: dylibPath, mode: RTLD_NOW | RTLD_LOCAL)
            return dlsym(handle, symbolName) != nil
        }

        /// 卸载所有已加载的 dylib，释放 `dlopen` 句柄。
        public func unloadAll() {
            for (_, handle) in handlesByPath {
                dlclose(handle)
            }
            handlesByPath.removeAll()
        }

        private func openHandle(
            dylibPath: String,
            mode: Int32
        ) throws -> UnsafeMutableRawPointer {
            if let existing = handlesByPath[dylibPath] {
                return existing
            }

            guard let handle = dlopen(dylibPath, mode) else {
                let message = dlerror().map { String(cString: $0) } ?? "Unknown dlopen error."
                throw LoaderError.dlopenFailed(message: message)
            }

            handlesByPath[dylibPath] = handle
            return handle
        }
    }
}
