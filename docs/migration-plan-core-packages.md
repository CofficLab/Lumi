# LumiCoreKit 和 LumiAppKit 迁移计划

## 当前架构

```
LumiKernel (新)          LumiCoreKit (旧)
     ↓                        ↓
  Plugins                LumiAppKit
                              ↓
                        LumiFactory
                              ↓
                        主应用
```

## 目标架构

```
LumiKernel (核心)
     ↓
LumiFactory (组装层)
     ↓
主应用
```

## 迁移步骤

### Phase 1: 保留并共存 (当前)
- ✅ LumiKernel 作为新的插件架构核心
- ✅ LumiCoreKit 保留，继续提供核心类型和服务
- ✅ LumiAppKit 保留，提供应用层UI

### Phase 2: 内容迁移 (下一步)
1. **LumiCoreKit → LumiKernel**
   - 迁移核心类型定义
   - 迁移工具类
   - 迁移服务（需要重构为 Provider 模式）

2. **LumiAppKit + LumiFactory 合并**
   - 统一UI组装层
   - 消除重复代码
   - 简化依赖关系

### Phase 3: 核心包重构
- 重构 EditorService、AgentToolKit 等包
- 将对 LumiCoreKit 的依赖改为 LumiKernel
- 清理旧的协议和类型

### Phase 4: 清理
- 删除 LumiCoreKit 中已迁移的内容
- 考虑重命名或删除 LumiAppKit

## 不应该删除的原因

### LumiCoreKit
1. **核心类型** - 定义了整个系统的基础类型
2. **核心服务** - 提供基础设施服务
3. **过渡期必要** - 避免一次性大规模重构风险

### LumiAppKit
1. **应用层UI** - 包含大量应用层视图和逻辑
2. **服务组装** - 提供应用级服务
3. **与 LumiFactory 功能重叠** - 需要先合并再清理

## 下一步行动建议

1. **短期**：保持现状，先完成插件迁移的集成测试
2. **中期**：逐步将 LumiCoreKit 的内容迁移到 LumiKernel
3. **长期**：合并 LumiAppKit 和 LumiFactory，简化架构

---

**创建时间**: 2026-07-19
**状态**: 规划中