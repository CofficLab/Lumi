import Foundation
import KitProjectDetect

/// 项目类型检测
///
/// 判定规则由 `KitProjectDetect` 提供：那里是唯一一份「清单文件 → 项目类型」的映射，
/// 聊天空态的项目卡也用它，两边不会给出互相矛盾的类型。
public enum ProjectTypeSection {
    /// 根据项目根目录文件推断项目类型
    public static func render(at root: URL) -> String {
        ProjectTypeDetector.detect(at: root).displayText ?? "Unknown"
    }
}
