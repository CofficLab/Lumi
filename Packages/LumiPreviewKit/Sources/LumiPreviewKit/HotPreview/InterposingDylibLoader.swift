import Darwin
import Foundation

public extension LumiPreviewPackage {
    actor InterposingDylibLoader {
        public struct LoadedImage: Sendable, Equatable {
            public let path: String
            public let symbolName: String?

            public init(path: String, symbolName: String?) {
                self.path = path
                self.symbolName = symbolName
            }
        }

        public enum LoaderError: Error, Equatable, LocalizedError {
            case missingDylib(path: String)
            case dlopenFailed(message: String)
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

        public func resolveSymbol(
            named symbolName: String,
            in dylibPath: String
        ) throws -> Bool {
            let handle = try openHandle(dylibPath: dylibPath, mode: RTLD_NOW | RTLD_LOCAL)
            return dlsym(handle, symbolName) != nil
        }

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
