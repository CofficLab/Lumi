# 项目开发通用规则

> 本规范定义了 Lumi 项目的通用开发规则和指导方针。

---

## 项目信息

- **平台**: macOS APP
- **技术栈**: SwiftUI, Swift, MagicKit

---

## 通用规则

### 1. 文档管理

在完成代码修改、重构或功能开发后，**禁止**创建或更新 README 文件。

### 2. 构建要求

无需构建，除非用户明确说明。

### 3. 错误处理

如果任何函数会抛出错误，必须设计合理的视图来展示错误。

---

## 相关规范

- [数据存储规范](./plugin-storage-rules.md)
- [目录结构规范](./plugin-directory-rules.md)
- [国际化规范](./plugin-i18n-rules.md)
- [最少功能原则](./minimal-functionality.md)
