# TestPlan — PluginDatabaseManager

## 包概述

DatabaseManagerPlugin Manage SQLite, MySQL, PostgreSQL, and Redis

平台: macOS 14+, iOS 17+
测试文件: 6 个，用例总数: 95

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
- **PostgreSQL 对象列举默认 schema**（3 条）：由 `loadObjectsUsesCurrentSchemaFunctionWhenSchemaUnspecified`、`loadRoutinesUsesCurrentSchemaFunctionWhenSchemaUnspecified`、`loadObjectsBindsExplicitSchemaAsLiteral` 锁定（**回归 #275**）：未指定 schema 时表/视图/函数列举必须调用 `current_schema()` 函数而非字符串字面量，否则侧边栏漏掉当前 schema 的全部对象；显式 schema 仍按转义字面量过滤。改动 `PostgreSQLIntrospector.loadObjects` 的 schema 过滤时优先跑对应测试文件。
- **DatabaseConnectionDraft**（2 条）：由 `sqlitePathIsStoredVerbatim`、`sqlitePathRejectsWhitespaceOnlyInput` 锁定，防止连接表单改动合法文件路径。
- **DatabaseManagerV2Plugin**（1 条）：由 `restoresDatabaseWorkspace` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DatabaseViewModelConnectionRace**（4 条）：由 `slowQueryFromPreviousConnectionDoesNotOverwriteNewConnection`、`slowerConnectDoesNotReplaceNewerSelection`、`staleSQLiteTablesDoNotOverwriteNewDatabase`、`sidebarReloadBypassesSchemaCache` 锁定，防止旧连接/慢查询/旧表列表覆盖当前连接状态，以及 Reload 命中旧结构缓存。
- **SQLite RETURNING**（2 条）：由 `executeAcceptsReturningRows`、`returningStatementsUseQueryPath` 锁定；改动 DML 路由或 SQLite step 循环时优先跑对应测试文件。
- **SQLite WITH (CTE)**（2 条）：由 `withQueryUsesReadPath`、`withQueryReturnsRowsEndToEnd` 锁定；改动 SQL 读语句前缀判定（`isReadStatement`）时优先跑对应测试文件，防止只读 CTE 被误路由到 execute 而丢掉结果行。
- **Redis handshake**（2 条）：由 `errorResponseFailsHandshake`、`successResponsePassesHandshake` 锁定，防止 AUTH/PING 的 RESP 错误值被忽略。
- **Redis RESP parsing**（3 条）：由 `trailingCRIsIncomplete`、`CRFollowedByNonLFTimesOut`、`splitCRLFCompletesAfterNextChunk` 锁定，防止 TCP 在 CR/LF 间分片时误判。
- **Redis read-command routing**（2 条）：由 `redisReadCommandsUseQueryPath`、`redisWriteCommandsUseExecutePath` 锁定；改动 Redis 读命令判定（`isReadStatement` 的 redis 分支）时优先跑对应测试文件，防止 KEYS/TYPE 等只读命令被误路由到 execute 而丢掉 RESP 内容，以及 GETSET/ZRANGESTORE 等写命令被前缀误判为读。
- **Redis key quoting**（2 条）：由 `quotedKeyRoundTripsAsSingleArgument`、`openRedisKeySendsSingleExactKeyArgument` 锁定（**回归 #282**）：含空格/引号/反斜杠的 Redis 键经 `RedisCommandParser.quote` 引用后，`tokenize` 必须还原为单个参数；`openRedisKey` 组合的 GET 经 `compose` 解析必须只携带一个完整键，不得被空格拆成多个参数而触发 wrong-argument-count。改动 `quote`/`tokenize` 或 `openRedisKey` 命令拼接时优先跑对应用例。
- **SQLStatementParser**（11 条）：由 `trailingOperatorDoesNotCrash`、`unterminatedBlockComment`、`trailingQuote` 等用例锁定，防止 SQL 以 `-`、`/`、`*` 或未闭合块注释结尾时把 `endIndex` 当成有效下标；并由 `dollarQuotedFunctionBodyIsSingleStatement`、`statementsOutsideDollarQuotesStillSplit` 等锁定（**回归 #279**）：PostgreSQL 美元引用（`$$...$$`、`$tag$...$tag$`）体内的分号不得被当成语句分隔符，函数体必须作为单条语句执行，引用之外的分号仍正常切分；位置参数 `$1` 不被误判为引用起始符。改动 `split`/`stripLiteralsAndComments` 时优先跑对应测试文件。

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
| 56 | 连接草稿 | SQLite 路径原样保存 | 路径含首尾空格 | 调用 `makeConfig` | `database` 与输入逐字节一致 | P0 | ✅ 已覆盖 | `sqlitePathIsStoredVerbatim` |
| 57 | 连接草稿 | 全空白 SQLite 路径被拒绝 | — | 调用 `makeConfig` | 抛出 `missingSQLitePath` | P0 | ✅ 已覆盖 | `sqlitePathRejectsWhitespaceOnlyInput` |
| 58 | 连接竞态 | 慢查询返回后不得覆盖已切换的连接状态 | 连接 A 执行挂起的慢查询，期间连接 B | 挂起 A 查询 → 连接 B → 放行 A 查询 | `selectedConfig` 仍为 B，`queryResult`/`errorMessage` 不被 A 写入，`isLoading` 为 false | P0 | ✅ 已覆盖 | `slowQueryFromPreviousConnectionDoesNotOverwriteNewConnection` |
| 59 | 连接竞态 | 更慢的旧连接完成后不得抢占新选中连接 | A 连接被挂起，B 先连接成功 | 挂起 A 连接 → 连接 B → 放行 A 连接 | `selectedConfig` 仍为 B，A 的陈旧连接被回收关闭 | P0 | ✅ 已覆盖 | `slowerConnectDoesNotReplaceNewerSelection` |
| 60 | SQLite RETURNING | SQLite DML RETURNING 产生结果行时不报告失败 | 临时 SQLite 库 | 执行 `INSERT ... RETURNING`（query）与 `UPDATE ... RETURNING`（execute），再查 count | INSERT 带回 id 行，execute 返回影响 1 行，count 为 1（仅写入一次） | P1 | ✅ 已覆盖 | `executeAcceptsReturningRows` |
| 61 | SQLite RETURNING | DML RETURNING 识别为读路径，字面量中的 RETURNING 不误判 | — | 调用 `isReadStatement` | INSERT/UPDATE/DELETE ... RETURNING 均返回 true；`VALUES('RETURNING')` 返回 false | P1 | ✅ 已覆盖 | `returningStatementsUseQueryPath` |
| 62 | Redis handshake | Redis 握手错误响应会转换为连接错误 | — | 用 WRONGPASS / NOAUTH 响应调用 `validateHandshake` | 两种响应都抛出 `DatabaseError` | P1 | ✅ 已覆盖 | `errorResponseFailsHandshake` |
| 63 | Redis handshake | Redis 握手成功响应不抛错 | — | 用 OK / PONG 响应调用 `validateHandshake` | 不抛错 | P1 | ✅ 已覆盖 | `successResponsePassesHandshake` |
| 64 | Redis RESP parsing | CR 位于缓冲区末尾时返回不完整 | — | 用 `+OK\r`、`$3\r`、`*1\r` 调用 `parseComplete` | 均返回 nil（等待下一块） | P1 | ✅ 已覆盖 | `trailingCRIsIncomplete` |
| 65 | Redis RESP parsing | CR 后跟非法字节仍报格式错误 | — | 用 `+OK\rX` 调用 `parseComplete` | 抛出 `DatabaseError` | P1 | ✅ 已覆盖 | `CRFollowedByNonLFTimesOut` |
| 66 | Redis RESP parsing | 下一块补全 LF 后可解析 | — | 用完整的 `+OK\r\n` 与 `$3\r\nfoo\r\n` 调用 `parseComplete` | 分别解析出 simpleString / bulkString | P1 | ✅ 已覆盖 | `splitCRLFCompletesAfterNextChunk` |
| 67 | 连接竞态 | Reload 侧边栏对象树必须绕过缓存重新查询数据库 | PG 假连接记录所有 SQL，首次连接已填充结构缓存 | 连接后调用 `refreshSidebarObjects()` | 发出的查询数比连接后增加 | P0 | ✅ 已覆盖 | `sidebarReloadBypassesSchemaCache` |
| 68 | 连接竞态 | 旧库的表列表晚到时不得覆盖新选中的库 | 卡住 A 库的 `sqlite_master` 查询，期间切到 B 库 | 挂起 A 表列表查询 → 连接 B → 放行 A 查询 | `selectedConfig` 仍为 B，`sqliteTables` 不被 A 的陈旧结果写入 | P0 | ✅ 已覆盖 | `staleSQLiteTablesDoNotOverwriteNewDatabase` |
| 69 | SQLStatementParser | 以 - / * 结尾的语句不会越界且保留内容 | 输入以单个 `-`、`/`、`*` 结尾 | 调用 `split` 与 `stripLiteralsAndComments` | 不崩溃，返回原语句 | P0 | ✅ 已覆盖 | `trailingOperatorDoesNotCrash` |
| 70 | SQLStatementParser | 末尾的单独 - / * 会被当成普通内容 | 输入仅一个 `-`、`/` 或 `*` | 调用 `split` | 返回包含该字符的单条语句 | P1 | ✅ 已覆盖 | `loneTrailingCharacters` |
| 71 | SQLStatementParser | 未闭合块注释不会越界且不产生可执行语句 | 输入含未闭合 `/*` | 调用 `split` | 只有注释的片段被过滤 | P0 | ✅ 已覆盖 | `unterminatedBlockComment` |
| 72 | SQLStatementParser | 行注释收尾与分号切分保持原有行为 | 输入含 `;-- trailing` 与末尾行注释 | 调用 `split` 与 `stripLiteralsAndComments` | 分号前语句保留，注释被剥离 | P1 | ✅ 已覆盖 | `lineCommentAtEnd` |
| 73 | SQLStatementParser | 末尾的单引号不会越界 | 输入以未闭合单引号结尾 | 调用 `split` 与 `stripLiteralsAndComments` | 不崩溃，字面量按原样处理 | P0 | ✅ 已覆盖 | `trailingQuote` |
| 74 | SQLite WITH (CTE) | WITH 查询识别为读路径，注释前缀与大小写不影响判定 | — | 调用 `isReadStatement` | 只读 CTE（含行/块注释前缀、小写）返回 true；普通 INSERT 返回 false | P1 | ✅ 已覆盖 | `withQueryUsesReadPath` |
| 75 | SQLite WITH (CTE) | WITH 查询经 query 路径返回真实结果行 | 临时 SQLite 库 | 对 `WITH x AS (SELECT 1 AS n) SELECT n FROM x;` 调用 `isReadStatement` 与 `query` | 判定为读；列为 `["n"]`，行为 `[[1]]` | P1 | ✅ 已覆盖 | `withQueryReturnsRowsEndToEnd` |
| 76 | Redis read-command routing | Redis 只读命令识别为读路径（含 KEYS/TYPE，大小写不敏感） | — | 对 KEYS/TYPE/EXISTS/TTL/HGETALL/MGET/INFO 及既有 GET/SCAN 等调用 `isReadStatement` | 均返回 true（含小写与首尾空格） | P1 | ✅ 已覆盖 | `redisReadCommandsUseQueryPath` |
| 77 | Redis read-command routing | Redis 写入命令仍走 execute，前缀相近的写命令不被误判为读 | — | 对 SET/DEL/HSET 及 GETSET/GETDEL/ZRANGESTORE/CONFIG SET 调用 `isReadStatement` | 均返回 false | P1 | ✅ 已覆盖 | `redisWriteCommandsUseExecutePath` |
| 78 | Redis key quoting | 含空格/引号/反斜杠的键经 quote 后必须还原为单个参数，不得被拆分（回归 #282） | — | 对 foo bar/空键/制表符/换行/双引号/单引号/反斜杠/混合键调用 `quote` 再 `tokenize` | `tokenize(quote(key)) == [key]`，且 `tokenize("GET " + quote(key)) == ["GET", key]` | P0 | ✅ 已覆盖 | `quotedKeyRoundTripsAsSingleArgument` |
| 79 | Redis key quoting | 侧边栏打开含空格的键时 GET 必须只携带一个完整键参数，不得被空格拆开（回归 #282） | 假 Redis 驱动/连接记录下发命令 | 连接 Redis 后调用 `openRedisKey("foo bar")`，对捕获命令复刻 `compose` | 解析结果为 `["GET", "foo bar"]`，而非 `["GET","foo","bar"]` | P0 | ✅ 已覆盖 | `openRedisKeySendsSingleExactKeyArgument` |

### 空行插入语句的方言生成（回归 #280）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 80 | 空行插入 | PostgreSQL 空行插入必须生成 DEFAULT VALUES，不得套用 MySQL 的 () VALUES ()（回归 #280） | 带主键的表 t | `addInsert()` 后 `generatedInsertStatements(for: .postgresql)` | 等于 `INSERT INTO "t" DEFAULT VALUES;` | P0 | ✅ 已覆盖 | `postgresEmptyInsertUsesDefaultValues` |
| 81 | 空行插入 | MySQL 空行插入仍生成空列清单 () VALUES () | 带主键的表 t | `addInsert()` 后 `generatedInsertStatements(for: .mysql)` | 等于 ``INSERT INTO `t` () VALUES ();`` | P1 | ✅ 已覆盖 | `mysqlEmptyInsertUsesEmptyColumnList` |
| 82 | 空行插入 | SQLite 空行插入生成 DEFAULT VALUES | 带主键的表 t | `addInsert()` 后 `generatedInsertStatements(for: .sqlite)` | 等于 `INSERT INTO "t" DEFAULT VALUES;` | P1 | ✅ 已覆盖 | `sqliteEmptyInsertUsesDefaultValues` |
| 83 | 空行插入 | PostgreSQL 带 schema 的空行插入仍用 DEFAULT VALUES 且限定名正确 | schema=public 的表 t | `addInsert()` 后 `generatedInsertStatements(for: .postgresql)` | 等于 `INSERT INTO "public"."t" DEFAULT VALUES;` | P1 | ✅ 已覆盖 | `postgresEmptyInsertWithSchemaUsesDefaultValues` |

### PostgreSQL 对象列举的默认 schema（回归 #275）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 84 | 对象列举默认 schema | 未指定 schema 时表/视图列举必须调用 current_schema() 函数，不得当成字符串字面量（回归 #275） | 假 PG 连接记录 SQL | `loadObjects(of: .table, schema: nil)` | SQL 含 `table_schema = current_schema()`，不含 `table_schema = 'current_schema()'` | P0 | ✅ 已覆盖 | `loadObjectsUsesCurrentSchemaFunctionWhenSchemaUnspecified` |
| 85 | 对象列举默认 schema | 未指定 schema 时函数/存储过程列举必须调用 current_schema() 函数（回归 #275） | 假 PG 连接记录 SQL | `loadObjects(of: .function, schema: nil)` | SQL 含 `n.nspname = current_schema()`，不含 `n.nspname = 'current_schema()'` | P0 | ✅ 已覆盖 | `loadRoutinesUsesCurrentSchemaFunctionWhenSchemaUnspecified` |
| 86 | 对象列举默认 schema | 显式指定 schema 时仍按转义后的字符串字面量过滤 | 假 PG 连接记录 SQL | `loadObjects(of: .table, schema: "public")` | SQL 含 `table_schema = 'public'`，不含 `current_schema()` | P1 | ✅ 已覆盖 | `loadObjectsBindsExplicitSchemaAsLiteral` |

### 只读 PRAGMA 校验（回归 #272）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 87 | 只读 PRAGMA | 赋值形态的可写 PRAGMA 被拒绝，不得持久修改数据库（回归 #272） | — | 对 `PRAGMA user_version=123`/`journal_mode=WAL`/`foreign_keys=ON`/`writable_schema=ON`/`cache_size=2000`/`journal_mode='WAL'` 调用 `readonlySQL` | 均抛出 `DatabaseAgentToolError` | P0 | ✅ 已覆盖 | `readonlySQLRejectsWritablePragmaAssignment` |
| 88 | 只读 PRAGMA | 括号赋值形态的可写 PRAGMA 被拒绝（回归 #272） | — | 对 `PRAGMA cache_size(2000)`/`journal_mode(WAL)` 调用 `readonlySQL` | 均抛出 `DatabaseAgentToolError` | P0 | ✅ 已覆盖 | `readonlySQLRejectsWritablePragmaParenForm` |
| 89 | 只读 PRAGMA | 只读 PRAGMA 查询仍放行（裸读取与内省 pragma） | — | 对 `PRAGMA user_version`/`journal_mode`/`table_info(users)`/`index_list(users)`/`foreign_key_list(users)`/`integrity_check` 调用 `readonlySQL` | 均不抛错 | P1 | ✅ 已覆盖 | `readonlySQLAcceptsReadOnlyPragmaQueries` |

### PostgreSQL 美元引用切分（回归 #279）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 90 | 美元引用切分 | 美元引用函数体必须作为单条语句，不得按体内分号拆分（回归 #279） | — | 对 `CREATE FUNCTION ... AS $$ BEGIN PERFORM 1; PERFORM 2; END; $$ LANGUAGE plpgsql;` 调用 `split` | 仅 1 条语句，等于去掉尾部分号的原文 | P0 | ✅ 已覆盖 | `dollarQuotedFunctionBodyIsSingleStatement` |
| 91 | 美元引用切分 | 带标签 `$body$` 与嵌套 `$outer$/$inner$` 的引用同样保持单条语句（回归 #279） | — | 对带标签函数体与嵌套引用调用 `split` | 各返回单条完整语句，体内分号不切分 | P0 | ✅ 已覆盖 | `taggedAndNestedDollarQuotesAreSingleStatement` |
| 92 | 美元引用切分 | 美元引用之外的分号仍正常切分，不得过度合并（回归 #279） | — | 对 `SELECT 1; SELECT $$a;b$$; SELECT 2` 调用 `split` | 返回 3 条：`SELECT 1`、`SELECT $$a;b$$`、`SELECT 2` | P0 | ✅ 已覆盖 | `statementsOutsideDollarQuotesStillSplit` |
| 93 | 美元引用切分 | 位置参数 `$1`/`$2` 不被当成美元引用起始符（回归 #279） | — | 对 `SELECT $1; SELECT $2` 与 `SELECT $1` 调用 `split` | 分别返回 2 条与 1 条，`$1` 按普通字符处理 | P1 | ✅ 已覆盖 | `positionalParametersAreNotDollarQuotes` |
| 94 | 美元引用切分 | 美元引用体在骨架中被剥离，写关键字不参与只读判定（回归 #279） | — | 对 `SELECT $$DROP TABLE t; DELETE$$ AS s` 调用 `stripLiteralsAndComments` | 骨架不含 `DROP`/`DELETE`，保留 `SELECT` 与 `AS s` | P1 | ✅ 已覆盖 | `dollarQuotedBodyStrippedFromSkeleton` |
| 95 | 美元引用切分 | 美元引用体内的引号与分号不提前结束引用（回归 #279） | — | 对 `SELECT $tag$a'x'b; c$tag$ AS s; SELECT 2` 调用 `split` | 返回 2 条，第一条完整保留体内引号与分号 | P1 | ✅ 已覆盖 | `dollarQuoteIgnoresInnerQuotesAndSemicolons` |

> 说明：全部 **95 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 47 / 47
- P1: 已覆盖 47 / 47
- P2: 已覆盖 1 / 1
- **合计: 95 / 95**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（47 条）
- **P1**: 其余功能性用例（47 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 95 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
