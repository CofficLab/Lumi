# LibGit2Swift Tests

这是 LibGit2Swift 包的完整单元测试套件。

## 测试结构

### 测试辅助文件

- **`TestHelpers.swift`** - 提供 `TestGitRepository` 类，用于创建和管理测试用的临时 Git 仓库
- **`LibGit2SwiftTestCase.swift`** - 所有测试的基类，提供通用的测试设置和清理功能

### 测试文件

1. **`RepositoryTests.swift`** - 仓库检测和基本操作测试
   - 仓库识别
   - 根目录获取
   - HEAD 引用
   - 当前分支
   - 空仓库检测

2. **`StatusTests.swift`** - 状态检查测试
   - 未提交更改检测
   - 状态详情获取
   - 已暂存/未暂存文件列表
   - 待提交文件检查
   - Porcelain 状态格式

3. **`BranchTests.swift`** - 分支操作测试
   - 分支列表获取
   - 创建/删除/重命名分支
   - 从提交创建分支
   - 分支属性验证
   - 远程分支操作

4. **`CommitTests.swift`** - 提交操作测试
   - 提交列表获取
   - 分页获取提交
   - 提交详情
   - 分支提交历史
   - 提交属性验证
   - 标签关联提交

5. **`AddTests.swift`** - 文件暂存测试
   - 添加单个/多个文件
   - 添加修改/删除的文件
   - 添加所有文件
   - 模式匹配添加
   - 子目录文件处理
   - 文件状态转换

6. **`CheckoutTests.swift`** - 检出操作测试
   - 分支切换
   - 创建并切换分支
   - 文件检出（丢弃更改）
   - 提交检出（分离 HEAD）
   - 远程分支检出
   - 冲突处理

7. **`RemoteTests.swift`** - 远程仓库测试
   - 添加/删除远程仓库
   - 重命名远程仓库
   - 更新远程 URL
   - 获取远程列表
   - 远程仓库属性

8. **`ConfigTests.swift`** - 配置管理测试
   - 设置/获取配置
   - 用户名和邮箱配置
   - 多级配置
   - 配置持久化
   - 分支特定配置
   - 特殊字符处理

## 运行测试

### 运行所有测试

```bash
cd /Users/angel/Code/Coffic/GitOK/Packages/LibGit2Swift
swift test
```

### 运行特定测试

```bash
# 运行 Repository 测试
swift test --filter RepositoryTests

# 运行 Status 测试
swift test --filter StatusTests
```

### 运行测试并生成覆盖率报告

```bash
swift test --enable-code-coverage
```

## 测试覆盖范围

当前测试套件覆盖了以下 LibGit2Swift 功能：

- ✅ Repository 检测和基本操作
- ✅ 状态检查
- ✅ 分支管理
- ✅ 提交历史查看
- ✅ 文件暂存
- ✅ 分支和文件检出
- ✅ 远程仓库管理
- ✅ Git 配置管理

## 测试最佳实践

### Test Helpers 使用

所有测试都应该继承 `LibGit2SwiftTestCase` 并使用 `testRepo` 来访问测试仓库：

```swift
final class MyTests: LibGit2SwiftTestCase {
    func testSomething() throws {
        // testRepo 已经自动创建并初始化
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Content",
            message: "Test commit"
        )

        // 执行测试...
    }
}
```

### TestDataGenerator

使用 `TestDataGenerator` 生成随机测试数据：

```swift
let fileName = TestDataGenerator.randomFileName()
let branchName = TestDataGenerator.randomBranchName()
let commitMessage = TestDataGenerator.randomCommitMessage()
```

### 断言辅助方法

使用提供的断言辅助方法：

```swift
assertFileExists("file.txt", in: testRepo)
assertFileNotExists("deleted.txt", in: testRepo)
assertThrowsError(try someOperation(), errorType: LibGit2Error.self)
```

## 测试隔离

每个测试方法都会：
1. 在 `setUp` 中创建一个新的临时 Git 仓库
2. 在 `tearDown` 中清理临时目录

这确保了测试之间完全隔离，不会相互影响。

## 注意事项

1. **libgit2 初始化** - 测试会自动初始化和关闭 libgit2
2. **临时文件** - 所有测试文件都在 `/tmp/LibGit2SwiftTests/` 下创建
3. **异步操作** - 使用 `waitForAsyncOperation` 方法处理异步测试
4. **错误处理** - 使用 `XCTAssertThrowsError` 验证预期的错误

## 添加新测试

要添加新的测试：

1. 在相应的测试文件中创建新的测试方法
2. 继承自 `LibGit2SwiftTestCase`
3. 使用 `testRepo` 进行测试操作
4. 适当使用 `TestDataGenerator` 生成测试数据

示例：

```swift
func testNewFeature() throws {
    // Arrange
    try testRepo.createFileAndCommit(
        fileName: "test.txt",
        content: "Content",
        message: "Initial commit"
    )

    // Act
    let result = try LibGit2.someMethod(at: testRepo.repositoryPath)

    // Assert
    XCTAssertNotNil(result, "Result should not be nil")
}
```

## 性能测试

某些测试包含性能基准测试，使用 `measure` 块：

```swift
func testCommitListPerformance() throws {
    // 设置...
    measure {
        _ = try? LibGit2.getCommitList(at: testRepo.repositoryPath)
    }
}
```

## 贡献指南

在添加新功能到 LibGit2Swift 时，请同时添加相应的测试：

1. 为新功能创建一个新的测试文件或在现有文件中添加测试
2. 确保测试覆盖正常流程和错误情况
3. 使用描述性的测试名称
4. 添加适当的文档注释
