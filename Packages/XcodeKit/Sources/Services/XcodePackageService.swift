import Foundation
import XcodeProj
import PathKit
import os
import SuperLogKit

/// Xcode Package Service：管理 Xcode 项目中的 Swift Package 依赖
///
/// 提供添加远程/本地 Swift Package 的能力，使用 XcodeProj 库操作 project.pbxproj 文件。
public final class XcodePackageService: SuperLog, @unchecked Sendable {

    public static let emoji = "📦"
    public static let verbose = true
    
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "xcode.package")
    
    public init() {}
    
    // MARK: - 添加远程 Swift Package
    
    /// 向 Xcode 项目添加远程 Swift Package
    ///
    /// - Parameters:
    ///   - projectPath: .xcodeproj 文件的路径
    ///   - repositoryURL: Package 的 Git 仓库 URL
    ///   - productName: 要链接的产品名称（如 "Alamofire"）
    ///   - versionRequirement: 版本规则（如 .upToNextMajorVersion("5.0.0")）
    ///   - targetName: 要链接 Package 的 Target 名称
    /// - Returns: 添加结果描述
    public func addRemotePackage(
        projectPath: String,
        repositoryURL: String,
        productName: String,
        versionRequirement: XCRemoteSwiftPackageReference.VersionRequirement,
        targetName: String
    ) async throws -> String {
        let projectURL = URL(fileURLWithPath: projectPath)
        guard projectURL.pathExtension == "xcodeproj" else {
            throw XcodePackageError.invalidProjectPath(projectPath)
        }
        
        // 加载项目
        let xcodeProj = try XcodeProj(pathString: projectURL.path)
        let project = try xcodeProj.pbxproj.rootProject() ?? xcodeProj.pbxproj.projects.first
        
        guard let project else {
            throw XcodePackageError.noProjectFound
        }
        
        // 检查是否已存在相同的 Package
        if let existing = project.remotePackages.first(where: { $0.repositoryURL == repositoryURL }) {
            // 已存在相同 URL 的 package，检查版本是否匹配
            if existing.versionRequirement != versionRequirement {
                if Self.verbose {
                    Self.logger.warning("\(Self.t)Package \(repositoryURL, privacy: .public) 已存在但版本规则不同")
                }
                // 更新版本要求
                existing.versionRequirement = versionRequirement
            }
            
            // 检查是否已链接到目标 target
            let target = project.targets.first(where: { $0.name == targetName })
            if let target, let dependencies = target.packageProductDependencies {
                if dependencies.contains(where: { $0.productName == productName }) {
                    return "Package \(productName) 已存在于项目并已链接到 target \(targetName)"
                }
            }
        }
        
        // 使用 XcodeProj 提供的方法添加 package
        try project.addSwiftPackage(
            repositoryURL: repositoryURL,
            productName: productName,
            versionRequirement: versionRequirement,
            targetName: targetName
        )
        
        // 保存项目文件
        try PBXProjWriteSupport.write(xcodeProj, pathString: projectURL.path, override: true)
        
        if Self.verbose {
            Self.logger.info("\(Self.t)成功添加远程 Package: \(repositoryURL, privacy: .public) -> \(productName)")
        }
        
        return formatSuccessResult(
            projectPath: projectPath,
            packageType: "remote",
            repositoryURL: repositoryURL,
            productName: productName,
            targetName: targetName,
            versionRequirement: versionRequirement
        )
    }
    
    // MARK: - 添加本地 Swift Package
    
    /// 向 Xcode 项目添加本地 Swift Package
    ///
    /// - Parameters:
    ///   - projectPath: .xcodeproj 文件的路径
    ///   - relativePath: Package 相对于项目根目录的路径
    ///   - productName: 要链接的产品名称
    ///   - targetName: 要链接 Package 的 Target 名称
    /// - Returns: 添加结果描述
    public func addLocalPackage(
        projectPath: String,
        relativePath: String,
        productName: String,
        targetName: String
    ) async throws -> String {
        let projectURL = URL(fileURLWithPath: projectPath)
        guard projectURL.pathExtension == "xcodeproj" else {
            throw XcodePackageError.invalidProjectPath(projectPath)
        }
        
        let path = Path(relativePath)
        guard path.isRelative else {
            throw XcodePackageError.pathMustBeRelative(relativePath)
        }
        
        // 加载项目
        let xcodeProj = try XcodeProj(pathString: projectURL.path)
        let project = try xcodeProj.pbxproj.rootProject() ?? xcodeProj.pbxproj.projects.first
        
        guard let project else {
            throw XcodePackageError.noProjectFound
        }
        
        // 检查是否已存在相同的本地 Package
        let existingLocal = project.localPackages.first(where: { $0.relativePath == relativePath })
        if existingLocal != nil {
            // 检查是否已链接到目标 target
            let target = project.targets.first(where: { $0.name == targetName })
            if let target, let dependencies = target.packageProductDependencies {
                if dependencies.contains(where: { $0.productName == productName }) {
                    return "本地 Package \(productName) 已存在于项目并已链接到 target \(targetName)"
                }
            }
        }
        
        // 使用 XcodeProj 提供的方法添加本地 package
        try project.addLocalSwiftPackage(
            path: path,
            productName: productName,
            targetName: targetName,
            addFileReference: true
        )
        
        // 保存项目文件
        try PBXProjWriteSupport.write(xcodeProj, pathString: projectURL.path, override: true)
        
        if Self.verbose {
            Self.logger.info("\(Self.t)成功添加本地 Package: \(relativePath, privacy: .public) -> \(productName)")
        }
        
        return formatSuccessResult(
            projectPath: projectPath,
            packageType: "local",
            relativePath: relativePath,
            productName: productName,
            targetName: targetName
        )
    }
    
    // MARK: - 查询现有 Package
    
    /// 获取项目中已有的 Swift Package 列表
    ///
    /// - Parameter projectPath: .xcodeproj 文件的路径
    /// - Returns: Package 信息列表
    public func listPackages(projectPath: String) async throws -> String {
        let projectURL = URL(fileURLWithPath: projectPath)
        guard projectURL.pathExtension == "xcodeproj" else {
            throw XcodePackageError.invalidProjectPath(projectPath)
        }
        
        let xcodeProj = try XcodeProj(pathString: projectURL.path)
        let project = try xcodeProj.pbxproj.rootProject() ?? xcodeProj.pbxproj.projects.first
        
        guard let project else {
            throw XcodePackageError.noProjectFound
        }
        
        var output = "# Swift Packages in \(projectURL.deletingPathExtension().lastPathComponent)\n\n"
        
        // 远程 Package
        let remotePackages = project.remotePackages
        if !remotePackages.isEmpty {
            output += "## Remote Packages\n\n"
            for pkg in remotePackages {
                output += "- **\(pkg.name ?? "Unknown")**\n"
                output += "  - URL: \(pkg.repositoryURL ?? "N/A")\n"
                if let version = pkg.versionRequirement {
                    output += "  - Version: \(formatVersionRequirement(version))\n"
                }
                output += "\n"
            }
        }
        
        // 本地 Package
        let localPackages = project.localPackages
        if !localPackages.isEmpty {
            output += "## Local Packages\n\n"
            for pkg in localPackages {
                output += "- **\(pkg.relativePath)**\n"
                output += "\n"
            }
        }
        
        if remotePackages.isEmpty && localPackages.isEmpty {
            output += "No Swift Package dependencies found.\n"
        }
        
        // 列出 Targets 及其链接的 Package Products
        output += "\n## Target Dependencies\n\n"
        for target in project.targets {
            let packageDeps = target.packageProductDependencies ?? []
            if !packageDeps.isEmpty {
                output += "- **\(target.name)**:\n"
                for dep in packageDeps {
                    output += "  - \(dep.productName)\n"
                }
            }
        }
        
        return output
    }
    
    // MARK: - Helper Methods
    
    private func formatSuccessResult(
        projectPath: String,
        packageType: String,
        repositoryURL: String? = nil,
        relativePath: String? = nil,
        productName: String,
        targetName: String,
        versionRequirement: XCRemoteSwiftPackageReference.VersionRequirement? = nil
    ) -> String {
        var output = "# Swift Package Added Successfully\n\n"
        output += "- **Project**: \(URL(fileURLWithPath: projectPath).lastPathComponent)\n"
        output += "- **Type**: \(packageType)\n"
        
        if packageType == "remote" {
            output += "- **Repository URL**: \(repositoryURL ?? "N/A")\n"
            if let version = versionRequirement {
                output += "- **Version**: \(formatVersionRequirement(version))\n"
            }
        } else {
            output += "- **Relative Path**: \(relativePath ?? "N/A")\n"
        }
        
        output += "- **Product Name**: \(productName)\n"
        output += "- **Linked to Target**: \(targetName)\n"
        output += "\n"
        output += "⚠️ **Note**: After adding a Swift Package, you should:\n"
        output += "1. Resolve packages in Xcode (File → Packages → Resolve Package Versions)\n"
        output += "2. Or run `xcodebuild -resolvePackageDependencies` from command line\n"
        
        return output
    }
    
    private func formatVersionRequirement(_ requirement: XCRemoteSwiftPackageReference.VersionRequirement) -> String {
        switch requirement {
        case .upToNextMajorVersion(let version):
            return "Up to Next Major (\(version))"
        case .upToNextMinorVersion(let version):
            return "Up to Next Minor (\(version))"
        case .range(let from, let to):
            return "Range (\(from) to \(to))"
        case .exact(let version):
            return "Exact (\(version))"
        case .branch(let branch):
            return "Branch (\(branch))"
        case .revision(let revision):
            return "Revision (\(revision))"
        }
    }
}

// MARK: - Errors

public enum XcodePackageError: LocalizedError, Sendable {
    case invalidProjectPath(String)
    case noProjectFound
    case pathMustBeRelative(String)
    case targetNotFound(String)
    case packageAlreadyExists(String)
    case writeFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidProjectPath(let path):
            return "Invalid Xcode project path: \(path). Expected .xcodeproj file."
        case .noProjectFound:
            return "No project found in the .xcodeproj file."
        case .pathMustBeRelative(let path):
            return "Local package path must be relative: \(path)"
        case .targetNotFound(let name):
            return "Target '\(name)' not found in the project."
        case .packageAlreadyExists(let name):
            return "Package '\(name)' already exists in the project."
        case .writeFailed(let path):
            return "Failed to write project file: \(path)"
        }
    }
}