# Lumi 版本管理脚本

## 概述

这套脚本用于自动管理 Lumi 项目中多个 target 的版本号，确保所有 target 的版本保持一致。

## Target 结构

- **Lumi** - 主应用程序
- **LumiFinder** - Finder 扩展

## 脚本说明

### 1. bump-version.sh
根据 Conventional Commits 规范分析提交历史，确定版本递增类型。

**规则：**
- `feat:` → minor 版本递增
- `fix:` → patch 版本递增
- `BREAKING CHANGE:` 或 `feat!` → major 版本递增

**输出：** `major` | `minor` | `patch`

### 2. calculate-version.sh
自动计算下一个版本号并更新 Xcode 项目文件。

**功能：**
- 读取当前版本号
- 根据提交历史计算新版本
- 批量更新所有 target 的 MARKETING_VERSION

**输出：** 新版本号（如 `1.2.3`）

### 3. sync-versions.sh
手动同步所有 target 的版本号。

**用法：**
```bash
# 自动同步（使用当前最高版本）
./.github/scripts/sync-versions.sh

# 指定版本和构建号
./.github/scripts/sync-versions.sh 1.2.3 42
```

## GitHub Actions

### 1. Sync Versions 工作流
- **触发条件：** 推送到 dev/main 分支，或手动触发
- **功能：** 自动同步所有 target 的版本号

### 2. Bump Version 工作流
- **触发条件：** 推送到 main 分支，或手动触发
- **功能：** 自动递增版本号并创建 Git 标签

## 使用建议

### 日常开发流程
```bash
# 1. 使用 Conventional Commits 提交代码
git commit -m "feat: 添加新功能"
git commit -m "fix: 修复 bug"

# 2. 合并到 main 分支后，GitHub Actions 自动：
#    - 分析提交类型
#    - 计算新版本号
#    - 更新所有 target
#    - 创建版本标签
```

### 手动发布版本
```bash
# 1. 更新版本号
./.github/scripts/sync-versions.sh 2.0.0 100

# 2. 提交更改
git add Lumi.xcodeproj/project.pbxproj
git commit -m "chore: release v2.0.0"
git push

# 3. 创建标签
git tag -a v2.0.0 -m "Release v2.0.0"
git push origin v2.0.0
```

## 版本号格式

- **MARKETING_VERSION**: `x.y.z` (如 `1.0.8`)
  - 对应 App Store 版本号
  - 遵循语义化版本规范
  
- **CURRENT_PROJECT_VERSION**: 数字 (如 `9`)
  - 对应构建号
  - 每次构建自动递增

## 验证版本一致性

检查所有 target 版本是否一致：
```bash
grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" Lumi.xcodeproj/project.pbxproj
```

输出应该显示所有 target 使用相同的版本号。
