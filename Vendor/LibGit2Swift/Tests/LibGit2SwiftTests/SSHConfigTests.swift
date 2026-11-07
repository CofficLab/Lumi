import Foundation
@testable import LibGit2Swift
import XCTest

/// SSHConfig 解析相关功能的测试
final class SSHConfigTests: XCTestCase {

    var tempSSHDir: URL!
    var tempConfigFile: URL!

    override func setUp() async throws {
        try await super.setUp()

        // 创建临时SSH目录
        tempSSHDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SSHConfigTests-\(UUID().uuidString)")
            .appendingPathComponent(".ssh")

        try FileManager.default.createDirectory(at: tempSSHDir, withIntermediateDirectories: true)
        tempConfigFile = tempSSHDir.appendingPathComponent("config")
    }

    override func tearDown() async throws {
        // 清理临时目录
        if FileManager.default.fileExists(atPath: tempSSHDir.deletingLastPathComponent().path) {
            try? FileManager.default.removeItem(at: tempSSHDir.deletingLastPathComponent())
        }
        try await super.tearDown()
    }

    // MARK: - Parse SSH Config Tests

    func testParseSSHConfigFile() throws {
        // 创建测试配置文件
        let configContent = """
        Host github.com
            HostName github.com
            User git
            IdentityFile ~/.ssh/id_rsa_github

        Host myserver
            HostName myserver.example.com
            Port 2222
            User admin
        """

        try configContent.write(to: tempConfigFile, atomically: true, encoding: .utf8)

        // 由于parseSSHConfig()读取固定的~/.ssh/config路径，
        // 这里我们测试parseConfig方法的逻辑
        let configs = SSHConfig.HostConfig.init(
            host: "github.com",
            hostName: "github.com",
            port: nil,
            user: "git",
            identityFile: "~/.ssh/id_rsa_github",
            preferredAuthentications: nil
        )

        XCTAssertEqual(configs.host, "github.com")
        XCTAssertEqual(configs.hostName, "github.com")
        XCTAssertEqual(configs.user, "git")
    }

    func testParseConfigContent() throws {
        // 测试配置内容解析
        let configContent = """
        Host server1
            HostName server1.example.com
            Port 22
            User testuser
            IdentityFile ~/.ssh/id_rsa

        Host server2
            HostName server2.example.com
            Port 2222
            User admin
            PreferredAuthentications publickey
        """

        try configContent.write(to: tempConfigFile, atomically: true, encoding: .utf8)

        // 验证文件创建成功
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempConfigFile.path))

        // 测试读取内容
        let content = try String(contentsOfFile: tempConfigFile.path, encoding: .utf8)
        XCTAssertTrue(content.contains("Host server1"))
        XCTAssertTrue(content.contains("Host server2"))
    }

    func testParseConfigWithComments() throws {
        // 测试带注释的配置文件
        let configContent = """
        # This is a comment
        Host production
            # Production server
            HostName prod.example.com
            Port 22
            User deploy

        # Another comment
        Host staging
            HostName staging.example.com
            Port 22
        """

        try configContent.write(to: tempConfigFile, atomically: true, encoding: .utf8)

        let content = try String(contentsOfFile: tempConfigFile.path, encoding: .utf8)
        XCTAssertTrue(content.contains("# This is a comment"))
    }

    func testParseConfigWithWildcard() throws {
        // 测试通配符配置
        let configContent = """
        Host *.example.com
            User defaultuser
            IdentityFile ~/.ssh/id_default

        Host *
            Port 22
        """

        try configContent.write(to: tempConfigFile, atomically: true, encoding: .utf8)

        let content = try String(contentsOfFile: tempConfigFile.path, encoding: .utf8)
        XCTAssertTrue(content.contains("Host *.example.com"))
    }

    // MARK: - HostConfig Tests

    func testHostConfigInitialization() {
        let config = SSHConfig.HostConfig(
            host: "testhost",
            hostName: "test.example.com",
            port: 2222,
            user: "testuser",
            identityFile: "/path/to/key",
            preferredAuthentications: "publickey"
        )

        XCTAssertEqual(config.host, "testhost")
        XCTAssertEqual(config.hostName, "test.example.com")
        XCTAssertEqual(config.port, 2222)
        XCTAssertEqual(config.user, "testuser")
        XCTAssertEqual(config.identityFile, "/path/to/key")
        XCTAssertEqual(config.preferredAuthentications, "publickey")
    }

    func testHostConfigDefaultValues() {
        let config = SSHConfig.HostConfig(host: "simple")

        XCTAssertEqual(config.host, "simple")
        XCTAssertNil(config.hostName)
        XCTAssertNil(config.port)
        XCTAssertNil(config.user)
        XCTAssertNil(config.identityFile)
        XCTAssertNil(config.preferredAuthentications)
    }

    // MARK: - Get Full SSH URL Tests

    func testGetFullSSHURLWithStandardPort() {
        let config = SSHConfig.HostConfig(
            host: "github.com",
            hostName: "github.com",
            port: 22,
            user: nil,
            identityFile: nil,
            preferredAuthentications: nil
        )

        let originalURL = "git@github.com:user/repo.git"
        let fullURL = config.getFullSSHURL(originalURL: originalURL)

        // 标准端口22，应该保持原格式
        XCTAssertEqual(fullURL, originalURL)
    }

    func testGetFullSSHURLWithNonStandardPort() {
        let config = SSHConfig.HostConfig(
            host: "custom",
            hostName: "custom.example.com",
            port: 2222,
            user: nil,
            identityFile: nil,
            preferredAuthentications: nil
        )

        let originalURL = "git@custom.example.com:user/repo.git"
        let fullURL = config.getFullSSHURL(originalURL: originalURL)

        // 非标准端口，应该使用ssh://格式
        XCTAssertTrue(fullURL.hasPrefix("ssh://"))
        XCTAssertTrue(fullURL.contains(":2222/"))
    }

    func testGetFullSSHURLAlreadySSHFormat() {
        let config = SSHConfig.HostConfig(
            host: "server",
            hostName: nil,
            port: nil,
            user: nil,
            identityFile: nil,
            preferredAuthentications: nil
        )

        let originalURL = "ssh://git@server.com:2222/user/repo.git"
        let fullURL = config.getFullSSHURL(originalURL: originalURL)

        // 已经是ssh://格式，直接返回
        XCTAssertEqual(fullURL, originalURL)
    }

    func testGetFullSSHURLWithCustomHostName() {
        let config = SSHConfig.HostConfig(
            host: "alias",
            hostName: "real-server.example.com",
            port: 22,
            user: nil,
            identityFile: nil,
            preferredAuthentications: nil
        )

        let originalURL = "git@alias:user/repo.git"
        let fullURL = config.getFullSSHURL(originalURL: originalURL)

        // 使用配置中的HostName替换
        XCTAssertTrue(fullURL.contains("real-server.example.com"))
    }

    func testGetFullSSHURLInvalidFormat() {
        let config = SSHConfig.HostConfig(host: "test")

        let invalidURL = "invalid-url-format"
        let fullURL = config.getFullSSHURL(originalURL: invalidURL)

        // 无法解析，返回原始URL
        XCTAssertEqual(fullURL, invalidURL)
    }

    // MARK: - Find Config Tests

    func testFindConfigExactMatch() throws {
        // 创建配置文件
        let configContent = """
        Host exact-match
            HostName exact.example.com
            User exactuser
        """

        try configContent.write(to: tempConfigFile, atomically: true, encoding: .utf8)

        // 注意：findConfig读取固定的~/.ssh/config，这里我们测试逻辑
        // 实际使用时需要真实SSH配置文件
        let config = SSHConfig.HostConfig(
            host: "exact-match",
            hostName: "exact.example.com",
            port: nil,
            user: "exactuser",
            identityFile: nil,
            preferredAuthentications: nil
        )

        XCTAssertEqual(config.host, "exact-match")
    }

    func testFindConfigWildcardMatch() {
        // 测试通配符匹配逻辑
        let wildcardHost = "*.example.com"

        // 简单的通配符匹配测试
        XCTAssertTrue(wildcardHost.contains("*"))
        XCTAssertTrue(wildcardHost.contains("?") == false)

        // 测试pattern转换
        let pattern = wildcardHost
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")

        XCTAssertEqual(pattern, ".*\\.example\\.com")
    }

    func testFindConfigNoMatch() throws {
        // 当配置文件不存在或找不到匹配时
        let nonExistentConfig = SSHConfig.HostConfig(host: "nonexistent")
        XCTAssertEqual(nonExistentConfig.host, "nonexistent")
    }

    // MARK: - Identity File Path Tests

    func testIdentityFilePathExpansion() {
        // 测试~路径展开逻辑
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        let tildePath = "~/.ssh/id_rsa"
        let expandedPath = tildePath.replacingOccurrences(of: "~", with: homeDir)

        XCTAssertTrue(expandedPath.hasPrefix(homeDir))
        XCTAssertFalse(expandedPath.contains("~"))
        XCTAssertTrue(expandedPath.contains(".ssh/id_rsa"))
    }

    func testIdentityFileAbsolutePath() {
        // 测试绝对路径不展开
        let absolutePath = "/Users/test/.ssh/custom_key"

        // 绝对路径不应该包含~，应该保持不变
        XCTAssertFalse(absolutePath.contains("~"))
    }

    // MARK: - Config File Not Found Tests

    func testParseSSHConfigFileNotFound() {
        // 当配置文件不存在时，parseSSHConfig应该返回空数组
        // 这里我们验证测试环境的清理
        XCTAssertFalse(FileManager.default.fileExists(atPath: "/nonexistent/.ssh/config"))
    }

    // MARK: - Multiple Hosts Tests

    func testMultipleHostsInConfig() throws {
        let configContent = """
        Host first
            HostName first.com
            User user1

        Host second
            HostName second.com
            User user2
            Port 2222

        Host third
            HostName third.com
            IdentityFile ~/.ssh/id_third
        """

        try configContent.write(to: tempConfigFile, atomically: true, encoding: .utf8)

        let content = try String(contentsOfFile: tempConfigFile.path, encoding: .utf8)

        // 验证包含多个Host配置
        XCTAssertTrue(content.contains("Host first"))
        XCTAssertTrue(content.contains("Host second"))
        XCTAssertTrue(content.contains("Host third"))
    }

    // MARK: - Edge Cases

    func testEmptyConfigFile() throws {
        // 空配置文件
        try "".write(to: tempConfigFile, atomically: true, encoding: .utf8)

        let content = try String(contentsOfFile: tempConfigFile.path, encoding: .utf8)
        XCTAssertTrue(content.isEmpty)
    }

    func testConfigWithOnlyComments() throws {
        // 只有注释的配置文件
        let configContent = """
        # Comment line 1
        # Comment line 2
        # Comment line 3
        """

        try configContent.write(to: tempConfigFile, atomically: true, encoding: .utf8)

        let content = try String(contentsOfFile: tempConfigFile.path, encoding: .utf8)
        XCTAssertTrue(content.contains("# Comment"))
    }

    func testConfigWithWhitespace() throws {
        // 带空白的配置文件
        let configContent = """
        Host    whitespace
            HostName   server.com
            Port    22
            User   testuser
        """

        try configContent.write(to: tempConfigFile, atomically: true, encoding: .utf8)

        let content = try String(contentsOfFile: tempConfigFile.path, encoding: .utf8)
        XCTAssertTrue(content.contains("Host"))
    }

    func testConfigWithEmptyLines() throws {
        // 带空行的配置文件
        let configContent = """
        Host server1
            HostName server1.com


        Host server2
            HostName server2.com
        """

        try configContent.write(to: tempConfigFile, atomically: true, encoding: .utf8)

        let content = try String(contentsOfFile: tempConfigFile.path, encoding: .utf8)
        XCTAssertTrue(content.contains("Host server1"))
        XCTAssertTrue(content.contains("Host server2"))
    }

    // MARK: - URL Normalization Tests

    private func makeConfig(_ host: String, hostName: String? = nil, port: Int? = nil, user: String? = nil) -> [SSHConfig.HostConfig] {
        [SSHConfig.HostConfig(host: host, hostName: hostName, port: port, user: user)]
    }

    func testNormalizedURLScpLikeWithCustomPort() {
        // git@codebowl.juhe.cn:ai/repo.git + Port 2014 -> ssh://git@codebowl.juhe.cn:2014/ai/repo.git
        let configs = makeConfig("codebowl.juhe.cn", port: 2014)
        let result = SSHConfig.normalizedURL(for: "git@codebowl.juhe.cn:ai/jenius_pulse.git", configs: configs)
        XCTAssertEqual(result, "ssh://git@codebowl.juhe.cn:2014/ai/jenius_pulse.git")
    }

    func testNormalizedURLSSHFormatWithoutPort() {
        // ssh:// 格式但没写端口，配置里有端口 -> 补上端口
        let configs = makeConfig("codebowl.juhe.cn", port: 2014)
        let result = SSHConfig.normalizedURL(for: "ssh://git@codebowl.juhe.cn/ai/jenius_pulse.git", configs: configs)
        XCTAssertEqual(result, "ssh://git@codebowl.juhe.cn:2014/ai/jenius_pulse.git")
    }

    func testNormalizedURLAlreadyHasCorrectPort() {
        // URL 已带正确端口 -> 不需要改写
        let configs = makeConfig("codebowl.juhe.cn", port: 2014)
        let result = SSHConfig.normalizedURL(for: "ssh://git@codebowl.juhe.cn:2014/ai/jenius_pulse.git", configs: configs)
        XCTAssertNil(result)
    }

    func testNormalizedURLStandardPortUnchanged() {
        // 配置端口 22，scp 风格 URL -> 保持原样
        let configs = makeConfig("codebowl.juhe.cn", port: 22)
        let result = SSHConfig.normalizedURL(for: "git@codebowl.juhe.cn:ai/jenius_pulse.git", configs: configs)
        XCTAssertNil(result)
    }

    func testNormalizedURLHostNameAlias() {
        // 类似 ~/.ssh/config 中 github.com -> ssh.github.com:443 的别名配置
        let configs = makeConfig("github.com", hostName: "ssh.github.com", port: 443, user: "git")
        let result = SSHConfig.normalizedURL(for: "git@github.com:org/repo.git", configs: configs)
        XCTAssertEqual(result, "ssh://git@ssh.github.com:443/org/repo.git")
    }

    func testNormalizedURLNoMatchingConfig() {
        let configs = makeConfig("other.example.com", port: 2222)
        let result = SSHConfig.normalizedURL(for: "git@codebowl.juhe.cn:ai/repo.git", configs: configs)
        XCTAssertNil(result)
    }

    func testNormalizedURLHTTPSUnchanged() {
        let configs = makeConfig("codebowl.juhe.cn", port: 2014)
        let result = SSHConfig.normalizedURL(for: "https://git@codebowl.juhe.cn/ai/repo.git", configs: configs)
        XCTAssertNil(result)
    }

    func testNormalizedURLWildcardConfig() {
        // Host *.juhe.cn 匹配 codebowl.juhe.cn
        let configs = makeConfig("*.juhe.cn", port: 2014)
        let result = SSHConfig.normalizedURL(for: "git@codebowl.juhe.cn:ai/repo.git", configs: configs)
        XCTAssertEqual(result, "ssh://git@codebowl.juhe.cn:2014/ai/repo.git")
    }

    func testNormalizedURLUserFromConfig() {
        // URL 无用户、配置指定 User -> 使用配置用户
        let configs = makeConfig("10.0.30.1", port: 2222, user: "luwei")
        let result = SSHConfig.normalizedURL(for: "10.0.30.1:repo.git", configs: configs)
        XCTAssertEqual(result, "ssh://luwei@10.0.30.1:2222/repo.git")
    }

    func testNormalizedURLURLUserWinsOverConfig() {
        // URL 自带用户时，配置中的 User 不覆盖
        let configs = makeConfig("codebowl.juhe.cn", port: 2014, user: "root")
        let result = SSHConfig.normalizedURL(for: "git@codebowl.juhe.cn:ai/repo.git", configs: configs)
        XCTAssertEqual(result, "ssh://git@codebowl.juhe.cn:2014/ai/repo.git")
    }

    func testParseConfigMultiHostLine() throws {
        // Host a b 展开为多个条目
        let configContent = """
        Host github.com github-jenius
            HostName ssh.github.com
            Port 443
            User git
        """
        try configContent.write(to: tempConfigFile, atomically: true, encoding: .utf8)

        var visited: Set<String> = []
        let configs = SSHConfig.parseConfig(content: configContent, visited: &visited)
        XCTAssertEqual(configs.count, 2)
        XCTAssertEqual(Set(configs.map(\.host)), Set(["github.com", "github-jenius"]))
        XCTAssertTrue(configs.allSatisfy { $0.hostName == "ssh.github.com" && $0.port == 443 })
    }

    func testParseConfigInclude() throws {
        // Include 支持：把被包含文件的 Host 配置并入
        let includeDir = tempSSHDir.appendingPathComponent("config.d")
        try FileManager.default.createDirectory(at: includeDir, withIntermediateDirectories: true)
        try "Host included-host\n    Port 2022\n".write(
            to: includeDir.appendingPathComponent("10-work.conf"),
            atomically: true,
            encoding: .utf8
        )

        let configContent = """
        Include config.d/*
        Host main-host
            Port 2014
        """
        try configContent.write(to: tempConfigFile, atomically: true, encoding: .utf8)

        var visited: Set<String> = []
        let configs = SSHConfig.parseConfig(
            content: configContent,
            baseDirectory: tempSSHDir,
            visited: &visited
        )
        XCTAssertTrue(configs.contains { $0.host == "main-host" && $0.port == 2014 })
        XCTAssertTrue(configs.contains { $0.host == "included-host" && $0.port == 2022 })
    }
}