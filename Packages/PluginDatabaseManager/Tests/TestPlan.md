# TestPlan — PluginDatabaseManager

## 包概述

DatabaseManagerPlugin Manage SQLite, MySQL, PostgreSQL, and Redis

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 55

核心组件（源码目录）:
- `Agent/`
- `Core/`
- `Editor/`
- `Internal/`
- `Managers/`
- `Models/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `DatabaseManagerPluginSupport`
- `DatabaseAgentConnectionRegistry`
- `DatabaseConnectionSummary`
- `DatabaseListConnectionsV2Tool`
- `NewTableColumnDraft`
- `TableChangeManager`
- `SQLStatementParser`
- `StatementExecution`
- `DatabaseSQLLanguageSupport`
- `ConnectionPool`
- `DatabaseManagerCore`
- `DatabaseType`
- `MySQLDriver`
- `PostgreSQLDriver`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **DatabaseAgentToolService**（27 条）
- **DatabaseAgentToolServiceConnectionTests**（1 条）：真实 SQLite 连接复用规则，由 `queryReadonlyUsesUpdatedConfigWhenSavedConnectionIsEdited` 锁定。：由 `readonlySQLAcceptsSelect`、`readonlySQLPreservesExistingLimit`、`readonlySQLAcceptsPragmaForSQLite` 等用例锁定；改动该模块时优先跑对应测试文件。
- **只读策略**（10 条）：由 `readonlySQLAllowsWriteKeywordInsideStringLiteral`、`readonlySQLStillRejectsWriteKeywordOutsideLiteral` 等用例锁定；改动只读 SQL 判定或字面量/注释剥离时优先跑对应测试文件。
- **PostgreSQL schema**（3 条）：由 `postgresSchemaFilterListsAllNonSystemSchemasByDefault`、`postgresSchemaFilterBindsRequestedSchemaAsParameter` 等用例锁定；改动 schema 描述的过滤条件时优先跑对应测试文件。
- **DatabaseManagerV2Plugin**（1 条）：由 `restoresDatabaseWorkspace` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | DatabaseAgentToolService | readonlySQLAcceptsSelect | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readonlySQLAcceptsSelect` |
| 2 | DatabaseAgentToolService | readonlySQLPreservesExistingLimit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readonlySQLPreservesExistingLimit` |
| 3 | DatabaseAgentToolService | readonlySQLAcceptsPragmaForSQLite | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readonlySQLAcceptsPragmaForSQLite` |
| 4 | DatabaseAgentToolService | readonlySQLAcceptsShowForMySQL | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readonlySQLAcceptsShowForMySQL` |
| 5 | DatabaseAgentToolService | readonlySQLRejectsEmptySQL | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `readonlySQLRejectsEmptySQL` |
| 6 | DatabaseAgentToolService | readonlySQLRejectsRedis | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `readonlySQLRejectsRedis` |
| 7 | DatabaseAgentToolService | readonlySQLRejectsMultipleStatements | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `readonlySQLRejectsMultipleStatements` |
| 8 | DatabaseAgentToolService | readonlySQLAllowsTrailingSemicolon | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readonlySQLAllowsTrailingSemicolon` |
| 9 | DatabaseAgentToolService | readonlySQLRejectsWriteKeywords | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `readonlySQLRejectsWriteKeywords` |
| 10 | DatabaseAgentToolService | readonlySQLRejectsNonSelectFirstKeyword | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `readonlySQLRejectsNonSelectFirstKeyword` |
| 11 | DatabaseAgentToolService | readonlySQLRejectsDeleteStatement | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `readonlySQLRejectsDeleteStatement` |
| 12 | DatabaseAgentToolService | readonlySQLDoesNotAutoInjectLimitForExplain | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readonlySQLDoesNotAutoInjectLimitForExplain` |
| 13 | DatabaseAgentToolService | quoteIdentifierMySQLUsesBackticks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `quoteIdentifierMySQLUsesBackticks` |
| 14 | DatabaseAgentToolService | quoteIdentifierSQLiteUsesDoubleQuotes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `quoteIdentifierSQLiteUsesDoubleQuotes` |
| 15 | DatabaseAgentToolService | quoteIdentifierPostgreSQLUsesDoubleQuotes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `quoteIdentifierPostgreSQLUsesDoubleQuotes` |
| 16 | DatabaseAgentToolService | quoteIdentifierEscapesEmbeddedBacktick | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `quoteIdentifierEscapesEmbeddedBacktick` |
| 17 | DatabaseAgentToolService | quoteIdentifierEscapesEmbeddedDoubleQuote | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `quoteIdentifierEscapesEmbeddedDoubleQuote` |
| 18 | DatabaseAgentToolService | quoteIdentifierPathJoinsComponents | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `quoteIdentifierPathJoinsComponents` |
| 19 | DatabaseAgentToolService | normalizedLimitDefaultsWhenNil | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizedLimitDefaultsWhenNil` |
| 20 | DatabaseAgentToolService | normalizedLimitAcceptsInt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizedLimitAcceptsInt` |
| 21 | DatabaseAgentToolService | normalizedLimitAcceptsDouble | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizedLimitAcceptsDouble` |
| 22 | DatabaseAgentToolService | normalizedLimitAcceptsNumericString | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizedLimitAcceptsNumericString` |
| 23 | DatabaseAgentToolService | normalizedLimitRejectsZero | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `normalizedLimitRejectsZero` |
| 24 | DatabaseAgentToolService | normalizedLimitRejectsAboveMax | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `normalizedLimitRejectsAboveMax` |
| 25 | DatabaseAgentToolService | normalizedLimitAcceptsBoundaryValues | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizedLimitAcceptsBoundaryValues` |
| 26 | DatabaseAgentToolService | normalizedLimitRejectsGarbageString | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `normalizedLimitRejectsGarbageString` |
| 27 | DatabaseAgentToolService | connectionIdParsesValidUUID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `connectionIdParsesValidUUID` |
| 28 | DatabaseAgentToolService | connectionIdRejectsEmpty | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `connectionIdRejectsEmpty` |
| 29 | DatabaseAgentToolService | connectionIdRejectsNil | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `connectionIdRejectsNil` |
| 30 | DatabaseAgentToolService | connectionIdRejectsMalformed | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `connectionIdRejectsMalformed` |
| 31 | DatabaseAgentToolService | valueStringInteger | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `valueStringInteger` |
| 32 | DatabaseAgentToolService | valueStringNegativeInteger | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `valueStringNegativeInteger` |
| 33 | DatabaseAgentToolService | valueStringDouble | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `valueStringDouble` |
| 34 | DatabaseAgentToolService | valueStringBool | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `valueStringBool` |
| 35 | DatabaseAgentToolService | valueStringNull | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `valueStringNull` |
| 36 | DatabaseAgentToolService | valueStringDataShowsByteCount | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `valueStringDataShowsByteCount` |
| 37 | DatabaseAgentToolService | valueStringTruncatesLongStrings | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `valueStringTruncatesLongStrings` |
| 38 | DatabaseAgentToolService | valueStringDoesNotTruncateAtBoundary | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `valueStringDoesNotTruncateAtBoundary` |
| 39 | DatabaseAgentToolService | rowsAsDictionariesMapsValues | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rowsAsDictionariesMapsValues` |
| 40 | DatabaseAgentToolService | rowsAsDictionariesTruncatesAndFlags | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rowsAsDictionariesTruncatesAndFlags` |
| 41 | DatabaseManagerV2Plugin | V2 plugin restores workspace, SQL grammar, and SQLite external-file routing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `restoresDatabaseWorkspace` |

| 42 | 只读策略 | 字面量里的写关键字不触发拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `readonlySQLAllowsWriteKeywordInsideStringLiteral` |
| 43 | 只读策略 | 比较条件字面量里的写关键字不触发拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `readonlySQLAllowsWriteKeywordInsideComparisonLiteral` |
| 44 | 只读策略 | 字面量里的分号不视为多语句 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `readonlySQLAllowsSemicolonInsideStringLiteral` |
| 45 | 只读策略 | 行注释里的写关键字不触发拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `readonlySQLAllowsWriteKeywordInsideComment` |
| 46 | 只读策略 | 块注释里的写关键字不触发拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `readonlySQLAllowsWriteKeywordInsideBlockComment` |
| 47 | 只读策略 | 返回给执行层的语句保留字面量原文 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `readonlySQLPreservesLiteralContentInReturnedStatement` |
| 48 | 只读策略 | 字面量之外的多语句仍被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `readonlySQLStillRejectsMultipleStatements` |
| 49 | 只读策略 | 字面量之外的裸写关键字仍被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `readonlySQLStillRejectsWriteKeywordOutsideLiteral` |
| 50 | 只读策略 | 字面量之后的写语句仍被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `readonlySQLStillRejectsWriteStatementAfterLiteral` |
| 51 | 只读策略 | 字面量内的转义引号不影响剥离 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `readonlySQLHandlesEscapedQuoteInsideLiteral` |
| 52 | PostgreSQL schema | 未指定 schema 时列出所有非系统 schema | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `postgresSchemaFilterListsAllNonSystemSchemasByDefault` |
| 53 | PostgreSQL schema | 指定 schema 时走绑定参数 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `postgresSchemaFilterBindsRequestedSchemaAsParameter` |
| 54 | PostgreSQL schema | 空白 schema 视为未指定 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `postgresSchemaFilterTreatsBlankSchemaAsUnspecified` |
| 55 | 连接复用 | 编辑已保存连接后 Agent 不复用旧连接 | 旧库与新库各有一张表，同 id 换库 | 先查询旧库，再更新配置后查询 | 第二次查询读到新库表，且不再出现旧库表；断开后重连到当前配置 | P0 | ✅ 已覆盖 | `queryReadonlyUsesUpdatedConfigWhenSavedConnectionIsEdited` |

> 说明：全部 **55 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 28 / 28
- P1: 已覆盖 26 / 26
- P2: 已覆盖 1 / 1
- **合计: 55 / 55**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（15 条）
- **P1**: 其余功能性用例（25 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 54 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginDatabaseManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
