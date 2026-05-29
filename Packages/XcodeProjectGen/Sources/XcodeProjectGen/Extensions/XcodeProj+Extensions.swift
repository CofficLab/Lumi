import Foundation
import XcodeProj
import PathKit

// MARK: - PBXNativeTarget 便捷方法

extension PBXNativeTarget {
    /// 获取或创建 Frameworks Build Phase。
    func ensureFrameworksBuildPhase(in pbxProj: PBXProj) -> PBXFrameworksBuildPhase {
        if let existing = buildPhases.first(where: { $0 is PBXFrameworksBuildPhase }) as? PBXFrameworksBuildPhase {
            return existing
        }
        let phase = PBXFrameworksBuildPhase()
        pbxProj.add(object: phase)
        buildPhases.append(phase)
        return phase
    }

    /// 获取或创建 Sources Build Phase。
    func ensureSourcesBuildPhase(in pbxProj: PBXProj) -> PBXSourcesBuildPhase {
        if let existing = buildPhases.first(where: { $0 is PBXSourcesBuildPhase }) as? PBXSourcesBuildPhase {
            return existing
        }
        let phase = PBXSourcesBuildPhase()
        pbxProj.add(object: phase)
        buildPhases.append(phase)
        return phase
    }

    /// 获取或创建 Resources Build Phase。
    func ensureResourcesBuildPhase(in pbxProj: PBXProj) -> PBXResourcesBuildPhase {
        if let existing = buildPhases.first(where: { $0 is PBXResourcesBuildPhase }) as? PBXResourcesBuildPhase {
            return existing
        }
        let phase = PBXResourcesBuildPhase()
        pbxProj.add(object: phase)
        buildPhases.append(phase)
        return phase
    }

    /// 获取或创建 Headers Build Phase（用于 Framework）。
    func ensureHeadersBuildPhase(in pbxProj: PBXProj) -> PBXHeadersBuildPhase {
        if let existing = buildPhases.first(where: { $0 is PBXHeadersBuildPhase }) as? PBXHeadersBuildPhase {
            return existing
        }
        let phase = PBXHeadersBuildPhase()
        pbxProj.add(object: phase)
        buildPhases.append(phase)
        return phase
    }
}

// MARK: - PBXGroup 文件添加

extension PBXGroup {
    /// 添加一个源文件引用并自动添加到 Sources Build Phase。
    @discardableResult
    func addSourceFile(
        path: String,
        fileName: String,
        fileType: String = "sourcecode.swift",
        toSourcesBuildPhase buildPhase: PBXSourcesBuildPhase,
        in pbxProj: PBXProj
    ) -> (PBXFileReference, PBXBuildFile) {
        let fileRef = PBXFileReference(
            sourceTree: .group,
            name: fileName,
            lastKnownFileType: fileType,
            path: path
        )
        pbxProj.add(object: fileRef)
        children.append(fileRef)

        let buildFile = PBXBuildFile(file: fileRef)
        pbxProj.add(object: buildFile)
        buildPhase.files?.append(buildFile)

        return (fileRef, buildFile)
    }

    /// 添加一个资源文件引用并自动添加到 Resources Build Phase。
    @discardableResult
    func addResourceFile(
        path: String,
        fileName: String,
        fileType: String,
        toResourcesBuildPhase buildPhase: PBXResourcesBuildPhase,
        in pbxProj: PBXProj
    ) -> (PBXFileReference, PBXBuildFile) {
        let fileRef = PBXFileReference(
            sourceTree: .group,
            name: fileName,
            lastKnownFileType: fileType,
            path: path
        )
        pbxProj.add(object: fileRef)
        children.append(fileRef)

        let buildFile = PBXBuildFile(file: fileRef)
        pbxProj.add(object: buildFile)
        buildPhase.files?.append(buildFile)

        return (fileRef, buildFile)
    }

    /// 添加一个子 Group。
    @discardableResult
    func addGroup(
        name: String,
        path: String? = nil,
        in pbxProj: PBXProj
    ) -> PBXGroup {
        let group = PBXGroup(
            children: [],
            sourceTree: .group,
            name: name,
            path: path ?? name
        )
        pbxProj.add(object: group)
        children.append(group)
        return group
    }
}

// MARK: - Xcode 文件类型查询

extension Xcode {
    /// 常用文件类型映射。
    private static let fileTypeMap: [String: String] = [
        "swift": "sourcecode.swift",
        "m": "sourcecode.c.objc",
        "mm": "sourcecode.cpp.objcpp",
        "c": "sourcecode.c.c",
        "cpp": "sourcecode.cpp.cpp",
        "h": "sourcecode.c.h",
        "hpp": "sourcecode.c.h",
        "plist": "text.plist.xml",
        "json": "text.json",
        "xib": "file.xib",
        "storyboard": "file.storyboard",
        "xcassets": "folder.assetcatalog",
        "strings": "text.plist.strings",
        "stringsdict": "text.plist.stringsdict",
        "png": "image.png",
        "jpg": "image.jpeg",
        "jpeg": "image.jpeg",
        "pdf": "image.pdf",
        "framework": "wrapper.framework",
        "dylib": "compiled.mach-o.dylib",
        "bundle": "wrapper.cfbundle",
        "modulemap": "sourcecode.module",
    ]

    /// 根据文件扩展名获取 Xcode 文件类型标识符。
    ///
    /// - Parameter ext: 文件扩展名（不含点号）。
    /// - Returns: 对应的 Xcode 文件类型字符串，如果未知则返回 `nil`。
    public static func fileType(forExtension ext: String) -> String? {
        fileTypeMap[ext.lowercased()]
    }
}

// MARK: - PBXProductType 便捷属性

extension PBXProductType {
    /// 产品文件扩展名。
    ///
    /// - `application` → "app"
    /// - `framework` → "framework"
    /// - `staticLibrary` → "a"
    /// - `unitTestBundle` → "xctest"
    /// - 等
    var displayName: String {
        switch self {
        case .application: return "App"
        case .framework: return "Framework"
        case .staticLibrary: return "Static Library"
        case .dynamicLibrary: return "Dynamic Library"
        case .unitTestBundle: return "Unit Test Bundle"
        case .uiTestBundle: return "UI Test Bundle"
        case .appExtension: return "App Extension"
        case .extensionKitExtension: return "Extension Kit Extension"
        case .xpcService: return "XPC Service"
        case .bundle: return "Bundle"
        case .commandLineTool: return "Command Line Tool"
        @unknown default: return "Unknown"
        }
    }
}
