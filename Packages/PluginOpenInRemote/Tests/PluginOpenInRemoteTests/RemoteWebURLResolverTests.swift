import Foundation
import Testing
@testable import PluginOpenInRemote

/// 锁定「Git remote 地址 → 浏览器可访问的 HTTPS 链接」的转换规则。
///
/// 这些用例是插件最核心的行为契约：转换规则一旦漂移，用户点击标题栏按钮
/// 就会打开错误的地址。
@Suite("RemoteWebURLResolver")
struct RemoteWebURLResolverTests {
    @Test("scp-like 地址转换为 HTTPS web 链接")
    func convertsScpLikeRemote() {
        #expect(
            RemoteWebURLResolver.webURL(fromRemote: "git@github.com:user/repo.git")?
                .absoluteString == "https://github.com/user/repo"
        )
    }

    @Test("scp-like 地址缺少 .git 后缀时同样正确转换")
    func convertsScpLikeRemoteWithoutGitSuffix() {
        #expect(
            RemoteWebURLResolver.webURL(fromRemote: "git@github.com:user/repo")?
                .absoluteString == "https://github.com/user/repo"
        )
    }

    @Test("scp-like 地址保留多级分组路径")
    func convertsScpLikeRemoteWithGroupPath() {
        #expect(
            RemoteWebURLResolver.webURL(fromRemote: "git@gitlab.example.com:group/sub/repo.git")?
                .absoluteString == "https://gitlab.example.com/group/sub/repo"
        )
    }

    @Test("scp-like 地址丢弃 user@ 前缀")
    func stripsUserPrefixFromScpLikeRemote() {
        #expect(
            RemoteWebURLResolver.webURL(fromRemote: "user@github.com:user/repo.git")?
                .absoluteString == "https://github.com/user/repo"
        )
    }

    @Test("ssh:// 地址转换为 HTTPS web 链接并丢弃 SSH 端口")
    func convertsSSHRemote() {
        #expect(
            RemoteWebURLResolver.webURL(fromRemote: "ssh://git@github.com/user/repo.git")?
                .absoluteString == "https://github.com/user/repo"
        )
        #expect(
            RemoteWebURLResolver.webURL(fromRemote: "ssh://git@github.com:22/user/repo.git")?
                .absoluteString == "https://github.com/user/repo"
        )
    }

    @Test("git:// 地址转换为 HTTPS web 链接")
    func convertsGitProtocolRemote() {
        #expect(
            RemoteWebURLResolver.webURL(fromRemote: "git://github.com/user/repo.git")?
                .absoluteString == "https://github.com/user/repo"
        )
    }

    @Test("https 地址保持不变并去掉 .git 后缀")
    func normalizesHTTPSRemote() {
        #expect(
            RemoteWebURLResolver.webURL(fromRemote: "https://github.com/user/repo.git")?
                .absoluteString == "https://github.com/user/repo"
        )
        #expect(
            RemoteWebURLResolver.webURL(fromRemote: "https://github.com/user/repo")?
                .absoluteString == "https://github.com/user/repo"
        )
    }

    @Test("忽略首尾空白字符")
    func trimsWhitespaceAroundRemote() {
        #expect(
            RemoteWebURLResolver.webURL(fromRemote: "  git@github.com:user/repo.git  ")?
                .absoluteString == "https://github.com/user/repo"
        )
    }

    @Test("去掉结尾多余的斜杠")
    func stripsTrailingSlash() {
        #expect(
            RemoteWebURLResolver.webURL(fromRemote: "https://github.com/user/repo.git/")?
                .absoluteString == "https://github.com/user/repo"
        )
    }

    @Test("空地址与无法识别的地址返回 nil")
    func returnsNilForUnusableRemote() {
        #expect(RemoteWebURLResolver.webURL(fromRemote: "") == nil)
        #expect(RemoteWebURLResolver.webURL(fromRemote: "   ") == nil)
        #expect(RemoteWebURLResolver.webURL(fromRemote: "not-a-remote") == nil)
        #expect(RemoteWebURLResolver.webURL(fromRemote: "git@github.com:") == nil)
    }

    @Test("webURLString 与 webURL 结果一致")
    func webURLStringMatchesWebURL() {
        #expect(
            RemoteWebURLResolver.webURLString(fromRemote: "git@github.com:user/repo.git")
                == "https://github.com/user/repo"
        )
        #expect(RemoteWebURLResolver.webURLString(fromRemote: "not-a-remote") == nil)
    }
}
