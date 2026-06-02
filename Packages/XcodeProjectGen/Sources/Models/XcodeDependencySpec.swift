import Foundation

/// 依赖声明。
public enum XcodeDependencySpec: Sendable {
    /// 远程 Swift Package 依赖。
    case remote(
        url: String,
        product: String,
        versionRequirement: XcodeVersionRequirement
    )

    /// 本地 Swift Package 依赖。
    case local(
        path: String,
        product: String
    )

    /// 同项目内的 Target 依赖。
    case target(name: String)

    /// 系统 Framework 依赖（如 UIKit、Foundation）。
    case framework(name: String)
}

/// Swift Package 版本规则。
public enum XcodeVersionRequirement: Sendable {
    /// 从指定版本到下一个 Major 版本之前。
    case upToNextMajor(_ version: String)
    /// 从指定版本到下一个 Minor 版本之前。
    case upToNextMinor(_ version: String)
    /// 精确版本。
    case exact(_ version: String)
    /// 指定分支。
    case branch(_ name: String)
    /// 指定 commit revision。
    case revision(_ hash: String)
}
