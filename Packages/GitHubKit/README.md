# GitHubKit

GitHubKit 是 Lumi 的 GitHub REST API 客户端包，封装仓库、搜索、文件内容、Issue 和评论相关模型与请求方法。

## 功能

- GitHub 仓库信息查询与仓库搜索
- 仓库文件内容读取与 Base64 文本解码
- Issue 列表、详情、创建、更新、关闭和重新打开
- Issue 评论列表与评论创建
- 可注入 `GitHubTokenProviding`，由上层负责提供访问令牌

## 使用

```swift
import GitHubKit

let service = GitHubAPIService()
let repo = try await service.getRepoInfo(owner: "CofficLab", repo: "Lumi")
print(repo.fullName)
```

带 token 的用法：

```swift
struct TokenProvider: GitHubTokenProviding {
    let accessToken: String?
}

let service = GitHubAPIService(tokenProvider: TokenProvider(accessToken: "..."))
```

## 测试

```bash
swift test
```
