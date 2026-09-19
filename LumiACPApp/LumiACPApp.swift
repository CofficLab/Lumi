/// LumiACP 的 Xcode wrapper 入口。
///
/// 真正的 headless ACP 可执行文件由同 target 的 SwiftPM build phase 从
/// ACPBootstrap / FactoryLumiACP 构建后写入同一个 app bundle。这个最小
/// stub 只负责让 Xcode 生成标准 app 容器，避免把 ACP 的包图与 Lumi GUI
/// 的包图合并解析。
@main
struct LumiACPApp {
    static func main() {
        // Replaced by the Build ACP Executable phase before the app is consumed.
    }
}
