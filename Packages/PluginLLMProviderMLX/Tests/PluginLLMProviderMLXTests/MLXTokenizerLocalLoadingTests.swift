import Foundation
import Testing
@testable import PluginLLMProviderMLX

/// MLX 的 tokenizer 必须从**本地模型目录**加载，而不是走 Hub 解析。
///
/// ## 为什么要有这条测试
///
/// `MLXTokenizerLoader.load(from:)` 收到的是 Lumi 已下载完成的本地模型
/// 目录，却调用 `AutoTokenizer.from(pretrained: directory.absoluteString)`。
///
/// 在 swift-transformers 1.4.0 里，`pretrained` 是 **Hub repository 入口**，
/// 不是本地目录入口——本地目录应走 `from(modelFolder:)`。于是：
/// - 本地目录被当成 Hub repo id（形如 `file:///...`）解析；
/// - 离线时 Hub 抛 `Repository not available locally`，有效的本地
///   tokenizer 文件根本没被读取；
/// - 在线时也会尝试 Hub 解析，而不是读取传入的目录。
///
/// 结果是「模型显示已下载」并不代表能离线使用，MLX 模型的核心离线能力
/// 被破坏。
@Suite("MLX tokenizer 的本地加载")
struct MLXTokenizerLocalLoadingTests {

    /// 写出一个最小可用的本地 tokenizer 目录。
    ///
    /// `config.json` / `tokenizer.json` / `tokenizer_config.json` 是
    /// swift-transformers 本地加载路径读取的文件。
    private func makeLocalModelDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mlx-tokenizer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        try #"{"model_type":"gpt2"}"#.write(
            to: directory.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )
        try #"{"version":"1.0","truncation":null,"padding":null,"added_tokens":[],"normalizer":null,"pre_tokenizer":null,"post_processor":null,"decoder":null,"model":{"type":"BPE","vocab":{},"merges":[]}}"#.write(
            to: directory.appendingPathComponent("tokenizer.json"),
            atomically: true,
            encoding: .utf8
        )
        try #"{"tokenizer_class":"PreTrainedTokenizerFast"}"#.write(
            to: directory.appendingPathComponent("tokenizer_config.json"),
            atomically: true,
            encoding: .utf8
        )
        return directory
    }

    @Test("本地模型目录能直接加载出 tokenizer")
    func localDirectoryLoadsTokenizer() async throws {
        let directory = try makeLocalModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let loader = MLXTokenizerLoader()
        let tokenizer = try await loader.load(from: directory)

        #expect(tokenizer != nil)
    }

    @Test("本地目录缺少 tokenizer.json 时给出配置缺失错误")
    func missingTokenizerFileReportsConfigurationMissing() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mlx-tokenizer-missing-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        // 只有 config.json，没有 tokenizer.json。
        try #"{"model_type":"gpt2"}"#.write(
            to: directory.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )

        let loader = MLXTokenizerLoader()

        await #expect(throws: (any Error).self) {
            _ = try await loader.load(from: directory)
        }
    }
}
