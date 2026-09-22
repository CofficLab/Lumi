/// Xcode wrapper used to produce the LumiACP app bundle.
///
/// The Build ACP Executable phase replaces this stub with the executable linked
/// by SwiftPM. Keeping the MLX package graph outside Xcode's native linker is
/// required because Xcode omits the nested mlx-c submodule sources.
struct LumiACPApp {
    static func main() {
        // Replaced by the SwiftPM-built executable before code signing.
    }
}

LumiACPApp.main()
