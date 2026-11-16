# TestPlan — PluginDatabaseManager

## 包概述

DatabaseManagerPlugin Manage SQLite, MySQL, PostgreSQL, and Redis

平台: macOS 14+, iOS 17+
测试文件: 21 个，用例总数: 182

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
- **DatabaseViewModelConnectionRace**（6 条）：由 `slowQueryFromPreviousConnectionDoesNotOverwriteNewConnection`、`slowerConnectDoesNotReplaceNewerSelection`、`staleSQLiteTablesDoNotOverwriteNewDatabase`、`sidebarReloadBypassesSchemaCache` 锁定，防止旧连接/慢查询/旧表列表覆盖当前连接状态，以及 Reload 命中旧结构缓存；并由 `historyRecordsSubmittedSQLNotCurrentEditorText`、`staleQueryDoesNotRecordHistoryUnderNewConnection` 锁定（**回归 #284**）：查询历史必须归属真正提交执行的 SQL 与连接，不得记录 await 期间被改写的编辑器文本，也不得把旧连接的晚到结果记到新连接名下。改动 `executeQuery` 的历史归属或代次校验时优先跑对应测试文件。
- **SQLite RETURNING**（2 条）：由 `executeAcceptsReturningRows`、`returningStatementsUseQueryPath` 锁定；改动 DML 路由或 SQLite step 循环时优先跑对应测试文件。
- **SQLite WITH (CTE)**（2 条）：由 `withQueryUsesReadPath`、`withQueryReturnsRowsEndToEnd` 锁定；改动 SQL 读语句前缀判定（`isReadStatement`）时优先跑对应测试文件，防止只读 CTE 被误路由到 execute 而丢掉结果行。
- **Redis handshake**（2 条）：由 `errorResponseFailsHandshake`、`successResponsePassesHandshake` 锁定，防止 AUTH/PING 的 RESP 错误值被忽略。
- **Redis RESP parsing**（3 条）：由 `trailingCRIsIncomplete`、`CRFollowedByNonLFTimesOut`、`splitCRLFCompletesAfterNextChunk` 锁定，防止 TCP 在 CR/LF 间分片时误判。
- **Redis read-command routing**（2 条）：由 `redisReadCommandsUseQueryPath`、`redisWriteCommandsUseExecutePath` 锁定；改动 Redis 读命令判定（`isReadStatement` 的 redis 分支）时优先跑对应测试文件，防止 KEYS/TYPE 等只读命令被误路由到 execute 而丢掉 RESP 内容，以及 GETSET/ZRANGESTORE 等写命令被前缀误判为读。
- **Redis key quoting**（2 条）：由 `quotedKeyRoundTripsAsSingleArgument`、`openRedisKeySendsSingleExactKeyArgument` 锁定（**回归 #282**）：含空格/引号/反斜杠的 Redis 键经 `RedisCommandParser.quote` 引用后，`tokenize` 必须还原为单个参数；`openRedisKey` 组合的 GET 经 `compose` 解析必须只携带一个完整键，不得被空格拆成多个参数而触发 wrong-argument-count。改动 `quote`/`tokenize` 或 `openRedisKey` 命令拼接时优先跑对应用例。
- **SQLStatementParser**（11 条）：由 `trailingOperatorDoesNotCrash`、`unterminatedBlockComment`、`trailingQuote` 等用例锁定，防止 SQL 以 `-`、`/`、`*` 或未闭合块注释结尾时把 `endIndex` 当成有效下标；并由 `dollarQuotedFunctionBodyIsSingleStatement`、`statementsOutsideDollarQuotesStillSplit` 等锁定（**回归 #279**）：PostgreSQL 美元引用（`$$...$$`、`$tag$...$tag$`）体内的分号不得被当成语句分隔符，函数体必须作为单条语句执行，引用之外的分号仍正常切分；位置参数 `$1` 不被误判为引用起始符。改动 `split`/`stripLiteralsAndComments` 时优先跑对应测试文件。
- **Schema 缓存目标**（#559，4 条）：`SchemaCacheService.loadSchemas` 必须把结果写入 `schemasByConfig`，不得写进 `databasesByConfig`；加载 schema 不得覆盖数据库列表缓存，数据库与 schema 各维护自己的缓存，数据库缓存命中后不得重新查询。由 `SchemaCacheTargetTests` 锁定。
- **结构变更暂存幂等**（#560 / #561，6 条）：`SchemaChangeManager.stageDropIndex` 与 `stageRename` 必须先按名 `removeAll` 旧条目再追加，使同一索引的重复删除、同一原列的连续重命名收敛为单条 DDL（重命名折叠为 old→final），不得生成两条都从原对象出发的语句导致保存时第二条找不到对象、整个事务回滚；不同对象的变更各自保留，受保护索引仍拒绝删除。由 `SchemaChangeStagingIdempotencyTests` 锁定；改动暂存去重或 `statements(for:)` 时优先跑对应测试文件。
- **切换连接的缓存失效目标**（#558，4 条）：`DatabaseViewModel.connect` 切换连接时必须把「旧连接」`previousConfigId` 传给 `schemaCache.invalidate`，不得传新 `config.id`——否则新连接刚预加载的缓存被清、旧连接的 objects/databases/schemas/tableSchema 缓存残留，编辑旧连接后重连仍命中过期元数据；新连接缓存由 `refreshSidebarObjects`（refresh:true）重建并保留，首次连接（无旧连接）与重连同一配置（previousConfigId==config.id）的行为须保持。由 `SchemaCacheConnectionSwitchTests` 锁定；改动 `connect` 的缓存失效或 `SchemaCacheService.invalidate` 时优先跑对应测试文件。
- **主键行标识唯一性**（#555，5 条）：`TableChangeManager.rowKey` 必须对每个主键列做「列名 UTF-8 长度前缀 + 值类型标签 + 值 UTF-8 长度前缀」的规范编码，保证不同主键值产生唯一且可逆的 key；不得直接用 `"\(pk)=\(value.description)"` 以 `|` 拼接（含 `|`/`=` 的字符串会错位碰撞、同长度 BLOB 都描述成 "N bytes"、数字与同形字符串无法区分），否则两行的 `updatesByRow`/`deletedRowKeys` 相互覆盖，最终 UPDATE/DELETE 作用到错误主键。由 `TableChangeManagerRowKeyTests` 锁定；改动 `rowKey`/`rowKeyComponent` 时优先跑对应测试文件。
- **Redis TLS 传输安全**（#273，7 条）：`RedisDriver.connect` 必须把 `config.sslOption` 传给 `RedisConnection`，`RedisConnection.init` 必须按 `RedisTransportPlan.make` 的决策用 `RedisTransportSecurity.makeParameters` 构造 `NWParameters`，不得恒用 `.tcp`。校验强度须与 `TLSSupport.makeTLSConfiguration` 一致：disable/nil 明文；prefer TLS+不校验+可回退；require TLS+不校验+**绝不回退**；verifyCA TLS+仅校验 CA+绝不回退；verifyFull TLS+校验 CA/主机名+绝不回退。否则用户选择 TLS 后仍明文发送 AUTH，泄露凭据。由 `RedisTransportSecurityTests` 锁定；改动 Redis 连接传输层或 SSL 映射时优先跑对应测试文件。
- **字符串字面量的方言转义**（#582，6 条）：`sqlLiteral(for:dialect:)` 生成内联字符串字面量时必须按方言转义——MySQL 默认开启反斜杠转义（NO_BACKSLASH_ESCAPES 关闭），须先把 `\` 翻倍再转义单引号，否则用户输入的 `\n`/`\t`/`\0` 被静默改写成控制字符、保存后内容与编辑器所见不一致；SQLite/PostgreSQL 标准串里反斜杠是普通字符，只转义单引号。UPDATE/INSERT/DELETE 三处生成路径都须传入当前 `DatabaseType`。由 `TableChangeManagerStringEscapeTests` 锁定；改动 `sqlLiteral`/`escapeSQLString` 或语句生成时优先跑对应测试文件。
- **后台行数 COUNT 的表身份校验**（#565，2 条）：`refreshTableRowCount` 在 `await` 之后写回共享 `tableRowCount` 前必须比对 `openTableObject?.id == table.id` 与连接代次，否则打开表 A 后快速切到 B，A 的慢 `SELECT COUNT(*)` 晚到会覆盖 B 的行数，分页 bar 据此算出错误的总页数与 Next 可用性；`openObject` 切换时把 `tableRowCount` 重置为 nil，保证新表自行发起 COUNT。由 `DatabaseViewModelRowCountRaceTests` 用门闩构造「旧表 COUNT 晚到」锁定；改动 `refreshTableRowCount`/`loadTablePage` 的行数写回或 `openObject` 重置时优先跑对应测试文件。
- **结构变更与未保存数据编辑的冲突**（#583，5 条）：`saveSchemaChanges` 应用 DDL 前必须检查暂存的结构变更（`renameColumn` 的旧列名、`dropColumn` 的列名）是否与未保存数据编辑引用的列（`TableChangeManager.referencedColumnNames`：UPDATE 的 SET 列与主键 WHERE 列、INSERT 的列、DELETE 的主键列）相交；相交则明确报错并阻止，不得静默执行 DDL——否则数据变更管理器持有的旧 schema 快照会生成引用已不存在列名的 SQL（如 `UPDATE ... SET "name"`），保存必失败。不相交（重命名未被编辑引用的列）或无数据编辑时照常应用，且保留无关数据编辑。由 `DatabaseViewModelSchemaChangeConflictTests` 锁定；改动 `saveSchemaChanges` 的冲突守卫或 `referencedColumnNames` 时优先跑对应测试文件。
- **连接凭据持久化的失败传播**（#569，7 条）：`DatabaseConnectionStore.saveConfigs` 必须先完成全部密码的 Keychain 写入（`setReportingErrors`，失败抛出 `KeychainStoreError`），最后才把脱敏配置写入 `UserDefaults`；不得用吞错的 `set` 无论成败都落盘——否则 Keychain 写入失败（如锁定的 `errSecInteractionNotAllowed`）被静默忽略，界面把「密码已丢失」的配置呈现为保存成功，重启后 `loadConfigs` 无法恢复凭据。`DatabaseViewModel.addConfig`/`updateConfig`/`removeConfig` 改为 `throws` 且持久化成功才更新内存 `configs`，表单据此保留输入并报错；`KeychainStore` 可注入以便测试替换后端。由 `DatabaseConnectionCredentialPersistenceTests` 锁定；改动 `saveConfigs` 的落盘时机或视图模型的凭据保存链路时优先跑对应测试文件。
- **工具栏语句计数的 memo 与发布门禁**（#1254，9 条）：`MainView.toolbar` 不得在每次 body 求值时同步 `SQLStatementParser.split(queryText).count`——普通编辑与无关的 ViewModel 发布（`isLoading`/`queryResult`/`errorMessage`）都会在主线程重复整段词法解析，长脚本下卡顿。修复为 `StatementCountCache` 按文本 memo（文本不变命中缓存、不重复解析，文本变化才重算），`DatabaseViewModel.queryText` 的 `didSet` 经 `refreshStatementCount()` 更新存储值 `statementCount`（仅当计数变化才发布），init 手动 seeding 一次；工具栏读取 O(1) 的 `viewModel.statementCount`。由 `StatementCountCacheTests`（缓存语义）与 `DatabaseViewModelStatementCountTests`（VM 集成）锁定；改动 `StatementCountCache`、`queryText` 的 `didSet` 或工具栏计数来源时优先跑对应测试文件。
- **MySQL 重复列名按位置解码**（#585，4 条）：`MySQLConnection.query` 解码结果行时必须按 `columnDefinitions` 与 `values` 的位置对应逐列构造 `MySQLData`（`decodeRow`），不得对每个列定义调用 mysql-nio 的 `row.column(name)`——SQL 允许重复列名（`SELECT a.id, b.id`、多表 JOIN），而 `row.column(name)` 按名字返回**首个**匹配列，会让后面的同名列错显首列的值，界面静默展示错误数据；NULL 列也须按位置解码为 `.null`，不得回填首列值。唯一列名的正常路径行为须保持。由 `MySQLDuplicateColumnDecodingTests` 用手工拼装的 `ColumnDefinition41` 协议包构造重复列名 `MySQLRow` 锁定；改动 `decodeRow` 或结果行解码循环时优先跑对应测试文件。

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

### BLOB 单元格只读（回归 #281）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 96 | BLOB 单元格只读 | 提交 BLOB 占位文本不产生任何变更，原始二进制保留（回归 #281） | 表 t(id PK, b BLOB, name TEXT)，b=X'01' | 对 b 列暂存字符串 `<BLOB 1 bytes>` | 无变更、无 UPDATE 语句，显示值仍为原始二进制 | P0 | ✅ 已覆盖 | `blobPlaceholderCommitStagesNoChange` |
| 97 | BLOB 单元格只读 | 同一行的非 BLOB 列仍可正常编辑，只读限制按单元格生效 | 同上 | 对 name 列暂存 `Bob` | name 被暂存（1 处变更），b 列未被标记修改 | P1 | ✅ 已覆盖 | `nonBlobCellInSameRowStillStages` |

### 查询历史归属（回归 #284）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 98 | 查询历史归属 | 历史必须记录真正提交的 SQL，而非 await 期间被改写的编辑器文本（回归 #284） | 连接 A 执行挂起的慢查询 | 挂起 A 查询 → 改写编辑器为 SELECT 1（不切连接）→ 放行 A 查询 | 历史含真正提交的慢查询语句，不含被改写后的 SELECT 1 | P0 | ✅ 已覆盖 | `historyRecordsSubmittedSQLNotCurrentEditorText` |
| 99 | 查询历史归属 | 旧连接查询晚到时不得把历史记到新连接名下（回归 #284） | 连接 A 执行挂起的慢查询，期间切到 B | 挂起 A 查询 → 连接 B 并改写编辑器为 SELECT 1 → 放行 A 查询 | selectedConfig 仍为 B；历史不含记到 B 名下的条目，也不含从未在 B 执行的 SELECT 1 | P0 | ✅ 已覆盖 | `staleQueryDoesNotRecordHistoryUnderNewConnection` |

### Schema 缓存目标（回归 #559）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 100 | Schema 缓存目标 | 加载 schema 不得覆盖数据库缓存（回归 #559） | 假 PG 连接，databases=[app_db,analytics]，schemas=[public,reporting] | loadDatabases → loadSchemas → loadDatabases | 第三次仍返回 [app_db,analytics]，databasesByConfig 不被 schema 覆盖 | P0 | ✅ 已覆盖 | `loadSchemasDoesNotOverwriteDatabaseCache` |
| 101 | Schema 缓存目标 | 加载 schema 必须写入 schema 缓存而非数据库缓存（回归 #559） | 同上 | loadSchemas | 返回 [public,reporting]，schemasByConfig 命中，databasesByConfig 为 nil | P0 | ✅ 已覆盖 | `loadSchemasPopulatesSchemaCache` |
| 102 | Schema 缓存目标 | 加载数据库只写数据库缓存，不碰 schema 缓存（回归 #559） | 同上 | loadDatabases | databasesByConfig 命中，schemasByConfig 为 nil | P1 | ✅ 已覆盖 | `loadDatabasesPopulatesDatabaseCacheOnly` |
| 103 | Schema 缓存目标 | schema 加载后数据库缓存命中不得重新查询（回归 #559） | 同上 | loadDatabases → loadSchemas → loadDatabases | pg_database 查询仅 1 次（缓存命中） | P1 | ✅ 已覆盖 | `databaseCacheHitDoesNotRequeryAfterSchemaLoad` |

### 结构变更暂存幂等（回归 #560 / #561）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 104 | 暂存幂等 | 同一索引删除重复暂存只生成一条 DROP INDEX（回归 #561） | 表 t 含索引 idx_old | `stageDropIndex(idx_old)` 两次 | dropIndex 变更仅 1 条，statements 仅 1 条且含 DROP INDEX 与 idx_old | P0 | ✅ 已覆盖 | `repeatedIndexDropStagesOnce` |
| 105 | 暂存幂等 | 删除两个不同索引各自保留一条 DROP INDEX，收敛不误删 | 表 t 含 idx_a、idx_b | 暂存 idx_a、idx_b、再 idx_a | dropIndex 变更 2 条，statements 2 条分别含 idx_a、idx_b | P1 | ✅ 已覆盖 | `distinctIndexDropsBothStaged` |
| 106 | 暂存幂等 | 受保护索引仍拒绝删除，幂等收敛不放宽保护 | 表 t 含主键索引 primary | `stageDropIndex(primary)` | 抛出 `protectedIndex("primary")`，changes 为空 | P1 | ✅ 已覆盖 | `protectedIndexDropStillThrows` |
| 107 | 暂存幂等 | 同一原列连续两次重命名折叠为单条 RENAME（回归 #560） | 表 t 含列 old_name | `stageRename(old_name→middle_name)` 再 `stageRename(old_name→final_name)` | rename 变更仅 1 条，statements 仅 1 条含 old_name 与 final_name、不含 middle_name | P0 | ✅ 已覆盖 | `repeatedRenameFoldsToSingleStatement` |
| 108 | 暂存幂等 | 从已暂存的新名再次重命名生成顺序有效的链式 DDL | 表 t 含列 old_name | 暂存 old_name→middle_name，再对 middle_name 暂存 →final_name | statements 2 条：old_name→middle_name、middle_name→final_name | P1 | ✅ 已覆盖 | `renameFromPendingNameChainsValidDDL` |
| 109 | 暂存幂等 | 重命名两个不同列各自保留一条 RENAME，收敛不误删 | 表 t 含 old_name、other | 暂存 old_name→renamed_a、other→renamed_b | rename 变更 2 条，statements 2 条分别含 renamed_a、renamed_b | P1 | ✅ 已覆盖 | `distinctColumnRenamesBothStaged` |

### 切换连接的结构缓存失效目标（回归 #558）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 110 | 缓存失效目标 | 切换连接必须清掉旧连接的对象缓存，保留新连接的对象缓存（回归 #558） | 假 PG 连接，配置 A、B | connect(A) → connect(B) | objectsByKey 不含 configId==A 的键，含 configId==B 的键 | P0 | ✅ 已覆盖 | `switchInvalidatesPreviousObjectCache` |
| 111 | 缓存失效目标 | 切换连接必须清掉旧连接的数据库列表与 schema 缓存（回归 #558） | 假 PG 连接，A 已填充 databases/schemas | connect(A) → loadDatabases/loadSchemas(A) → connect(B) | databasesByConfig[A] 与 schemasByConfig[A] 均为 nil | P0 | ✅ 已覆盖 | `switchInvalidatesPreviousDatabaseAndSchemaCache` |
| 112 | 缓存失效目标 | 首次连接没有旧连接，新连接缓存照常建立 | 假 PG 连接，配置 A | connect(A) | objectsByKey 含 configId==A 的键 | P1 | ✅ 已覆盖 | `firstConnectKeepsNewObjectCache` |
| 113 | 缓存失效目标 | 重连同一配置仍清掉其旧缓存，避免编辑后命中过期元数据 | 假 PG 连接，A 已填充 databases | connect(A) → loadDatabases(A) → connect(A) | databasesByConfig[A] 为 nil（previousConfigId==config.id 仍失效） | P1 | ✅ 已覆盖 | `reconnectSameConfigRefreshesCache` |

### 主键行标识唯一性（回归 #555）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 114 | 主键行标识 | 复合主键含分隔符的两行编辑互不覆盖（回归 #555） | 复合主键 (a,b)，row1 a="x\|b=y"/b="z"，row2 a="x"/b="y\|b=z"（旧编码同 key） | 分别暂存两行 value 编辑 | changedCellCount=2，两条 UPDATE 各自命中自己的主键 | P0 | ✅ 已覆盖 | `compositePrimaryKeySeparatorCollisionKeepsBothEdits` |
| 115 | 主键行标识 | 复合主键含分隔符的两行删除都被保留（回归 #555） | 同 114 | 分别 toggleRowDeletion 两行 | pendingDeleteCount=2，两行均 isRowDeleted，两条 DELETE 各自主键 | P0 | ✅ 已覆盖 | `compositePrimaryKeyCollisionKeepsBothDeletions` |
| 116 | 主键行标识 | 同长度但内容不同的 BLOB 主键保持区分（回归 #555） | BLOB 主键，两行分别为 0x0102 与 0x0304（旧编码均 "2 bytes"） | 分别暂存两行 value 编辑 | changedCellCount=2，两条 UPDATE | P1 | ✅ 已覆盖 | `sameLengthBlobPrimaryKeysStayDistinct` |
| 117 | 主键行标识 | 不同字符串主键各自生成独立的 UPDATE（回归 #555） | 文本主键 id='a=b' 与 id='a' | 分别暂存两行 value 编辑 | 两条 UPDATE，WHERE 分别为 id='a=b' 与 id='a' | P1 | ✅ 已覆盖 | `distinctStringPrimaryKeysGenerateSeparateUpdates` |
| 118 | 主键行标识 | rowKey 对含分隔符/同形异值的主键给出不同标识（回归 #555） | 文本主键 | 比较 'a=b'/'a'、integer(1)/string("1")、'x\|y'/'x'、null/string("NULL") 的 rowKey | 各组 key 互不相同 | P1 | ✅ 已覆盖 | `rowKeyDistinguishesSeparatorLadenAndHomographValues` |

### Redis TLS 传输安全（回归 #273）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 119 | Redis TLS | disable 与未设置使用明文（回归 #273） | sslOption=nil/disable | 计算 `RedisTransportPlan.make` | usesTLS=false，不允许回退 | P1 | ✅ 已覆盖 | `disableAndNilUsePlaintext` |
| 120 | Redis TLS | require 启用 TLS、不校验证书、绝不回退明文（回归 #273） | sslOption=require | 计算 `make` | usesTLS=true，verification=none，不允许回退 | P0 | ✅ 已覆盖 | `requireEnablesTLSWithoutFallback` |
| 121 | Redis TLS | verify-ca 启用 TLS、仅校验 CA、绝不回退明文（回归 #273） | sslOption=verify-ca | 计算 `make` | usesTLS=true，verification=caOnly，不允许回退 | P0 | ✅ 已覆盖 | `verifyCAEnablesTLSWithCAOnlyVerification` |
| 122 | Redis TLS | verify-full 启用 TLS、校验 CA+主机名、绝不回退明文（回归 #273） | sslOption=verify-full | 计算 `make` | usesTLS=true，verification=full，不允许回退 | P0 | ✅ 已覆盖 | `verifyFullEnablesTLSWithFullVerification` |
| 123 | Redis TLS | prefer 启用 TLS、不校验证书、允许回退明文（回归 #273） | sslOption=prefer | 计算 `make` | usesTLS=true，verification=none，允许回退 | P1 | ✅ 已覆盖 | `preferEnablesTLSWithPlaintextFallback` |
| 124 | Redis TLS | TLS 计划构造的 NWParameters 含 TLS 协议，不得是明文（回归 #273） | prefer/require/verify-ca/verify-full | `makeParameters` | applicationProtocols 含 `NWProtocolTLS.Options` | P0 | ✅ 已覆盖 | `tlsPlansProduceTLSParameters` |
| 125 | Redis TLS | 明文计划构造的 NWParameters 不含 TLS 协议（回归 #273） | nil/disable | `makeParameters` | applicationProtocols 不含 TLS | P1 | ✅ 已覆盖 | `plaintextPlansProduceTCPParameters` |

### 字符串字面量的方言转义（回归 #582）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 126 | 字符串方言转义 | MySQL 字符串必须转义反斜杠，逐字节保留用户输入（回归 #582） | — | `sqlLiteral(for: .string("C:\new\test"), dialect: .mysql)` | 等于 `'C:\\new\\test'`（反斜杠翻倍） | P0 | ✅ 已覆盖 | `mysqlStringEscapesBackslash` |
| 127 | 字符串方言转义 | MySQL 字符串同时含单引号与反斜杠时两者都正确转义 | — | `sqlLiteral(for: .string("a\'b"), dialect: .mysql)` | 等于 `'a\\''b'` | P1 | ✅ 已覆盖 | `mysqlStringEscapesQuoteAndBackslash` |
| 128 | 字符串方言转义 | SQLite/PostgreSQL 标准串不转义反斜杠，只转义单引号 | — | 对 `C:\new\test` 与 `it's` 调用 sqlite/postgresql 字面量 | 反斜杠原样保留，单引号翻倍 | P1 | ✅ 已覆盖 | `standardDialectsKeepBackslashLiteral` |
| 129 | 字符串方言转义 | MySQL UPDATE 语句对含反斜杠的单元格值正确转义 | 表 t(id PK, name TEXT) | 暂存 name=`C:\new\test` 后 `generatedUpdateStatements(for: .mysql)` | SET 子句为 `` `name` = 'C:\\new\\test' `` | P1 | ✅ 已覆盖 | `mysqlUpdateEscapesBackslash` |
| 130 | 字符串方言转义 | MySQL INSERT 语句对含反斜杠的字符串正确转义 | 表 t(id PK, name TEXT) | 新增行设 name=`path\to` 后 `generatedInsertStatements(for: .mysql)` | VALUES 为 `('path\\to')` | P1 | ✅ 已覆盖 | `mysqlInsertEscapesBackslash` |
| 131 | 字符串方言转义 | MySQL DELETE 的主键字符串含反斜杠时也正确转义 | 文本主键表 t | 删除主键 `k\1` 的行后 `generatedDeleteStatements(for: .mysql)` | WHERE 为 `` `id` = 'k\\1' `` | P1 | ✅ 已覆盖 | `mysqlDeleteEscapesBackslashInPrimaryKey` |

### 文本单元格编辑保留原始值（回归 #554）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 132 | 文本编辑保值 | TEXT 列保留首尾空白，不被 trim（回归 #554） | 表 t(id PK, name TEXT) | `parseEditedValue("  padded  ", column: "name")` | 等于 `.string("  padded  ")` | P0 | ✅ 已覆盖 | `textColumnPreservesPaddedWhitespace` |
| 133 | 文本编辑保值 | TEXT 列的字面量 NULL 保留为字符串，不映射 SQL NULL（回归 #554） | 同上 | 对 `NULL`/`null` 调用 `parseEditedValue` | 均为 `.string`，非 `.null` | P0 | ✅ 已覆盖 | `textColumnPreservesLiteralNULL` |
| 134 | 文本编辑保值 | TEXT 列保留前导零，不被推断成整数（回归 #554） | 同上 | `parseEditedValue("00123", column: "name")` | 等于 `.string("00123")` | P0 | ✅ 已覆盖 | `textColumnPreservesLeadingZeros` |
| 135 | 文本编辑保值 | TEXT 列的空串保留为空字符串，不映射 SQL NULL（回归 #554） | 同上 | `parseEditedValue("", column: "name")` | 等于 `.string("")` | P0 | ✅ 已覆盖 | `textColumnPreservesEmptyString` |
| 136 | 文本编辑保值 | TEXT 列编辑生成的 UPDATE 把值内联为字符串字面量而非整数（回归 #554） | 表 t(id PK, name TEXT)，行 id=1 | 以 `parseEditedValue("00123")` 暂存 name 后 `generatedUpdateStatements(for: .mysql)` | 等于 ``UPDATE `t` SET `name` = '00123' WHERE `id` = 1;`` | P0 | ✅ 已覆盖 | `textColumnUpdateGeneratesStringLiteral` |
| 137 | 文本编辑保值 | 数值/布尔列仍按类型推断，空串与 NULL 仍映射 SQL NULL（无回归） | 表 t(id INTEGER PK, amount REAL, flag BOOLEAN) | 对各列调用 `parseEditedValue` | id→integer、amount→double、flag→bool；NULL/空串→null | P1 | ✅ 已覆盖 | `numericAndBooleanColumnsStillInferTypes` |
| 138 | 文本编辑保值 | 各方言文本类型变体都保留原始字符串，数值/布尔类型不算文本 | — | 对 TEXT/VARCHAR/NVARCHAR/CHAR/CLOB/JSON/UUID/ENUM 调用 `parseEditedCellValue(_:columnType:)`，并检查 `isTextColumnType` | 文本变体保留 `00123`/`NULL` 原文；INTEGER/BOOLEAN/DOUBLE PRECISION/BLOB 不算文本 | P1 | ✅ 已覆盖 | `textTypeVariantsPreserveRawString` |
| 139 | 文本编辑保值 | 未知/缺省列类型沿用既有推断，不破坏无 schema 的调用方（无回归） | — | 不传 columnType 调用 `parseEditedCellValue` | `123`→integer、`  x  `→string("x")、`NULL`→null | P1 | ✅ 已覆盖 | `unknownColumnTypeFallsBackToInference` |

### 可空主键的 NULL 比较（回归 #568）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 140 | 可空主键 NULL 比较 | NULL 主键的 UPDATE 用 IS NULL 而非 = NULL（回归 #568） | 表 notes(id TEXT PK 可空, body TEXT)，行 id=NULL | 暂存 body→after 后 `generatedUpdateStatements(for: .sqlite)` | 等于 `UPDATE "notes" SET "body" = 'after' WHERE "id" IS NULL;` | P0 | ✅ 已覆盖 | `nullPrimaryKeyUpdateUsesIsNull` |
| 141 | 可空主键 NULL 比较 | NULL 主键的 DELETE 用 IS NULL 而非 = NULL（回归 #568） | 同上 | 标记删除该行后 `generatedDeleteStatements(for: .sqlite)` | 等于 `DELETE FROM "notes" WHERE "id" IS NULL;` | P0 | ✅ 已覆盖 | `nullPrimaryKeyDeleteUsesIsNull` |
| 142 | 可空主键 NULL 比较 | 非 NULL 主键仍用 = 字面量，不被改成 IS NULL | 行 id='k1' 与 id='k2' | 暂存 k1 行更新、k2 行删除后生成 UPDATE/DELETE | WHERE 分别为 `"id" = 'k1'`、`"id" = 'k2'`，不含 IS NULL | P1 | ✅ 已覆盖 | `nonNullPrimaryKeyStillUsesEquals` |
| 143 | 可空主键 NULL 比较 | 复合主键按值混用 IS NULL 与 =，方言引号正确 | 复合主键 (a,b)，行 a=NULL/b='x' | 暂存 val→new 后生成 sqlite/mysql UPDATE | WHERE 为 `"a" IS NULL AND "b" = 'x'`（mysql 用反引号） | P1 | ✅ 已覆盖 | `compositePrimaryKeyMixesNullAndEquals` |
| 144 | 可空主键 NULL 比较 | 行级写入判定只认 UPDATE/DELETE，INSERT/SELECT 不算 | — | 对 UPDATE/DELETE/INSERT/SELECT 调用 `isRowTargetingWrite` | UPDATE/DELETE（含小写/前导空格）为 true，INSERT/SELECT 为 false | P1 | ✅ 已覆盖 | `isRowTargetingWriteDetectsUpdateAndDelete` |
| 145 | 可空主键 NULL 比较 | NULL 主键行的 UPDATE 在真实 SQLite 上命中并修改该行 | 临时 SQLite，notes(id TEXT PK, body)，插入 (NULL,'before') | 暂存 body→after，执行生成的 UPDATE | 影响 1 行，body 变为 after | P0 | ✅ 已覆盖 | `nullPrimaryKeyUpdateActuallyModifiesRow` |
| 146 | 可空主键 NULL 比较 | NULL 主键行的 DELETE 在真实 SQLite 上命中并删除该行 | 同上 | 标记删除该行，执行生成的 DELETE | 影响 1 行，count 为 0 | P0 | ✅ 已覆盖 | `nullPrimaryKeyDeleteActuallyRemovesRow` |
| 147 | 可空主键 NULL 比较 | 行级写入命中 0 行时回滚并报错，不清空暂存（回归 #568） | 假事务影响行数=0，暂存一处更新 | `saveChanges()` | errorMessage 非空，hasChanges 仍 true，事务回滚未提交 | P0 | ✅ 已覆盖 | `saveRollsBackWhenRowWriteAffectsNoRows` |
| 148 | 可空主键 NULL 比较 | 行级写入命中 1 行时正常提交并清空暂存 | 假事务影响行数=1，暂存一处更新 | `saveChanges()` | errorMessage 为空，hasChanges 为 false，事务提交未回滚 | P1 | ✅ 已覆盖 | `saveSucceedsWhenRowWriteAffectsOneRow` |

### BLOB 主键的二进制字面量（回归 #567）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 149 | BLOB 主键字面量 | SQLite/MySQL 的 BLOB 字面量为 X'十六进制'（回归 #567） | — | `sqlLiteral(for: .data(0x0102), dialect: .sqlite/.mysql)` | 均等于 `X'0102'` | P0 | ✅ 已覆盖 | `blobLiteralUsesHexForSQLiteAndMySQL` |
| 150 | BLOB 主键字面量 | PostgreSQL 的 BLOB 字面量为 decode('十六进制','hex') | — | `sqlLiteral(for: .data(0x0102), dialect: .postgresql)` | 等于 `decode('0102', 'hex')` | P1 | ✅ 已覆盖 | `blobLiteralUsesDecodeForPostgreSQL` |
| 151 | BLOB 主键字面量 | 空 BLOB 生成合法的空二进制字面量 | — | 对 `.data(Data())` 调用 sqlite/postgresql 字面量 | 分别为 `X''`、`decode('', 'hex')` | P1 | ✅ 已覆盖 | `emptyBlobLiteralIsValid` |
| 152 | BLOB 主键字面量 | BLOB 主键行的 UPDATE 用二进制字面量而非 NULL（回归 #567） | 表 files(id BLOB PK, name TEXT)，行 id=X'01' | 暂存 name→after 后生成 sqlite/mysql UPDATE | WHERE 为 `"id" = X'01'`（mysql 用反引号），非 NULL | P0 | ✅ 已覆盖 | `blobPrimaryKeyUpdateUsesHexLiteral` |
| 153 | BLOB 主键字面量 | BLOB 主键行的 DELETE 用二进制字面量而非 NULL（回归 #567） | 同上 | 标记删除该行后 `generatedDeleteStatements(for: .sqlite)` | 等于 `DELETE FROM "files" WHERE "id" = X'01';` | P0 | ✅ 已覆盖 | `blobPrimaryKeyDeleteUsesHexLiteral` |
| 154 | BLOB 主键字面量 | BLOB 主键行的 UPDATE 在真实 SQLite 上命中并修改该行 | 临时 SQLite，files(id BLOB PK, name)，插入 (x'01','before') | 暂存 name→after，执行生成的 UPDATE | 影响 1 行，name 变为 after | P0 | ✅ 已覆盖 | `blobPrimaryKeyUpdateActuallyModifiesRow` |
| 155 | BLOB 主键字面量 | BLOB 主键行的 DELETE 在真实 SQLite 上命中并删除该行 | 同上 | 标记删除该行，执行生成的 DELETE | 影响 1 行，count 为 0 | P0 | ✅ 已覆盖 | `blobPrimaryKeyDeleteActuallyRemovesRow` |

### 后台行数 COUNT 的表身份校验（回归 #565）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|--------|------|----------|
| 156 | 后台行数 COUNT 竞态 | 旧表的慢 COUNT 晚到时不得覆盖新表的行数（回归 #565） | 假连接按表名返回计数 A=999/B=20，挂起 A 的 COUNT | 打开 A 并挂起其 COUNT，切到 B 完成 B 的 COUNT，再放行 A 的晚到 COUNT | B 的 tableRowCount 仍为 20，不被 A 的 999 污染 | P0 | ✅ 已覆盖 | `staleCountFromPreviousTableDoesNotPolluteNewTable` |
| 157 | 后台行数 COUNT 竞态 | 当前表自己的 COUNT 正常写回行数 | 假连接 B=20，openTableObject=B | `refreshTableRowCount()` | tableRowCount 等于 20 | P1 | ✅ 已覆盖 | `currentTableCountIsWritten` |

### 结构变更与未保存数据编辑的冲突（回归 #583）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|--------|------|----------|
| 158 | 结构变更冲突 | referencedColumnNames 汇集 UPDATE/INSERT/DELETE 引用的列与主键 | TableChangeManager(table t, schema id/name/body) | 暂存 name 的 UPDATE、body 的 INSERT、整行 DELETE | 等于 Set(["id","name","body"]) | P1 | ✅ 已覆盖 | `referencedColumnNamesCollectsUpdateInsertDeleteColumns` |
| 159 | 结构变更冲突 | 重命名仍有未保存编辑的列必须被阻止，DDL 不执行（回归 #583） | 真实 SQLite t(id,name,body)，行 (1,'Alice','x') | 暂存 name→Bob 的数据编辑，再 stageRenameColumn name→title，saveSchemaChanges | tableSchemaError 非空，结构与数据编辑均保留，探针 SELECT name 仍为 Alice | P0 | ✅ 已覆盖 | `renameOfColumnWithPendingEditIsBlocked` |
| 160 | 结构变更冲突 | 删除仍有未保存编辑的列必须被阻止，DDL 不执行（回归 #583） | 同上 | 暂存 name→Bob 的数据编辑，再 stageDropColumn name，saveSchemaChanges | tableSchemaError 非空，结构与数据编辑均保留，探针 SELECT name 仍为 Alice | P0 | ✅ 已覆盖 | `dropOfColumnWithPendingEditIsBlocked` |
| 161 | 结构变更冲突 | 重命名未被编辑引用的列照常应用，且保留无关数据编辑 | 同上 | 暂存 body→y 的数据编辑，再 stageRenameColumn name→title，saveSchemaChanges | tableSchemaError 为空，结构变更已应用，数据编辑保留，探针 SELECT title 为 Alice | P1 | ✅ 已覆盖 | `renameOfUnreferencedColumnProceedsAndPreservesEdit` |
| 162 | 结构变更冲突 | 没有未保存数据编辑时重命名照常应用 | 同上，无数据编辑 | stageRenameColumn name→title，saveSchemaChanges | tableSchemaError 为空，结构变更已应用，探针 SELECT title 为 Alice | P1 | ✅ 已覆盖 | `renameWithNoPendingDataEditProceeds` |

### 连接凭据持久化的失败传播（回归 #569）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|--------|------|----------|
| 163 | 凭据持久化失败传播 | Keychain 写入失败时 saveConfigs 抛出且不落盘配置（回归 #569） | 注入返回 errSecInteractionNotAllowed 的假后端，隔离 configsKey | `saveConfigs([带密码配置], keychain: 失败store)` | 抛出 KeychainStoreError，UserDefaults 配置键仍为 nil | P0 | ✅ 已覆盖 | `saveConfigsPropagatesKeychainWriteFailureAndDoesNotPersist` |
| 164 | 凭据持久化失败传播 | Keychain 写入失败时保留此前已保存的配置（回归 #569） | 先用正常 store 保存 existing，再用失败 store 保存 [existing, added] | `saveConfigs([existing, added], keychain: 失败store)` | 抛出 KeychainStoreError，落盘配置仍为 1 条且 id==existing.id，added 未加入 | P0 | ✅ 已覆盖 | `saveConfigsFailureKeepsPreviouslySavedConfigs` |
| 165 | 凭据持久化失败传播 | 保存成功时配置脱敏落盘且密码写入 Keychain | 注入正常假后端 | `saveConfigs([带密码配置], keychain: store)` | 落盘配置 password 为 nil，假后端按 connection.<id> 存到密码原文 | P1 | ✅ 已覆盖 | `saveConfigsSuccessSanitizesPasswordAndStoresInKeychain` |
| 166 | 凭据持久化失败传播 | loadConfigs 从 Keychain 回填密码 | 注入正常假后端并保存带密码配置 | `loadConfigs(keychain: store)` | 返回配置 id 一致且 password 恢复为原文 | P1 | ✅ 已覆盖 | `loadConfigsRestoresPasswordFromKeychain` |
| 167 | 凭据持久化失败传播 | addConfig 在 Keychain 失败时抛出且配置列表不变（回归 #569） | 注入失败 store 的视图模型，记录 before 列表 | `addConfig(带密码配置)` | 抛出 KeychainStoreError，configs 的 id 列表与 before 一致且不含新配置，UserDefaults 配置键为 nil | P0 | ✅ 已覆盖 | `addConfigPropagatesKeychainFailureAndKeepsConfigsUnchanged` |
| 168 | 凭据持久化失败传播 | updateConfig 在 Keychain 失败时抛出且保留原配置（回归 #569） | 注入失败 store 的视图模型，configs=[existing] | 改名+改密码后 `updateConfig(edited)` | 抛出 KeychainStoreError，configs 首项 password/name 仍为原值，UserDefaults 配置键为 nil | P0 | ✅ 已覆盖 | `updateConfigPropagatesKeychainFailureAndKeepsOriginal` |
| 169 | 凭据持久化失败传播 | addConfig 成功时追加配置并脱敏持久化 | 注入正常 store 的视图模型 | `addConfig(带密码配置)` | configs 含新配置，落盘配置含新 id 且 password 为 nil，假后端存到密码原文 | P1 | ✅ 已覆盖 | `addConfigSuccessAppendsAndPersists` |

### 工具栏语句计数的 memo 与发布门禁（回归 #1254）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|--------|------|----------|
| 170 | 语句计数 memo | 缓存计数与 SQLStatementParser.split 结果一致 | — | 对 `SELECT 1; SELECT 2; SELECT 3;` 调用 `count(for:)` | 等于 `split(...).count`，为 3 | P1 | ✅ 已覆盖 | `countMatchesParserSplit` |
| 171 | 语句计数 memo | 文本不变时不得重复整段解析（memo 命中，回归 #1254） | — | 对同一文本连续调用 `count(for:)` 三次 | `parseCount == 1` | P0 | ✅ 已覆盖 | `repeatedSameTextDoesNotReparse` |
| 172 | 语句计数 memo | 文本变化时必须重新解析并更新计数（回归 #1254） | — | 先 `count(for: "SELECT 1;")` 再 `count(for: "SELECT 1; SELECT 2;")` | 第二次返回 2，`parseCount` 由 1 变 2 | P0 | ✅ 已覆盖 | `changedTextReparses` |
| 173 | 语句计数 memo | 纯注释脚本计数为 0 | — | `count(for: "-- just a comment\n/* block */")` | 返回 0 | P2 | ✅ 已覆盖 | `commentOnlyScriptCountsZero` |
| 174 | 语句计数 memo | 空脚本计数为 0 | — | `count(for: "")` | 返回 0 | P2 | ✅ 已覆盖 | `emptyScriptCountsZero` |
| 175 | 语句计数 VM 集成 | 初始化时按默认 queryText seeding statementCount | `DatabaseViewModel(loadSavedConfigs: false)` | 读取 `statementCount` | 等于 `split(queryText).count` | P1 | ✅ 已覆盖 | `statementCountSeededOnInit` |
| 176 | 语句计数 VM 集成 | statementCount 必须随 queryText 变化更新（回归 #1254） | 同上 | 依次设 queryText 为三语句、单语句脚本 | statementCount 分别为 3、1 | P0 | ✅ 已覆盖 | `statementCountTracksQueryTextChanges` |
| 177 | 语句计数 VM 集成 | 无关的 ViewModel 发布不得改变 statementCount（回归 #1254） | 同上，queryText 为两语句脚本 | 设 isLoading/queryResult/errorMessage 后读取 statementCount | 仍为 2，不被无关发布触发重算 | P0 | ✅ 已覆盖 | `unrelatedPublicationDoesNotChangeStatementCount` |
| 178 | 语句计数 VM 集成 | 重置为相同 queryText 时计数保持不变 | 同上 | 连续两次设 queryText 为同一两语句脚本 | statementCount 仍为 2 | P1 | ✅ 已覆盖 | `resettingSameQueryTextKeepsCount` |

### MySQL 重复列名按位置解码（回归 #585）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|--------|------|----------|
| 179 | MySQL 重复列名解码 | 重复列名按位置保留各自的值，不得都显示首列（回归 #585） | 两个同名 "id" 列，text 格式，值 "1"/"2" | 构造 MySQLRow 后 `decodeRow` | 等于 `[.string("1"), .string("2")]`，而非两列都 "1" | P0 | ✅ 已覆盖 | `duplicateColumnNamesKeepPositionalValues` |
| 180 | MySQL 重复列名解码 | JOIN 形态首尾同名列夹一个异名列，三列各按位置解码 | "id"/"name"/"id" 三列，值 "10"/"alice"/"20" | 构造 MySQLRow 后 `decodeRow` | 等于 `[.string("10"), .string("alice"), .string("20")]` | P0 | ✅ 已覆盖 | `joinLikeDuplicateNamesAcrossThreeColumnsDecodeByPosition` |
| 181 | MySQL 重复列名解码 | 重复列名中第二列为 NULL 时按位置解码为 null，不得回填首列值 | 两个同名 "id" 列，值 ["1", nil] | 构造 MySQLRow 后 `decodeRow` | 等于 `[.string("1"), .null]`，而非两列都 "1" | P0 | ✅ 已覆盖 | `duplicateColumnNameWithNullSecondValueDecodesPositionally` |
| 182 | MySQL 重复列名解码 | 唯一列名仍按位置正确解码（重构不回归正常路径） | "id"/"name" 两列，值 "1"/"alice" | 构造 MySQLRow 后 `decodeRow` | 等于 `[.string("1"), .string("alice")]` | P1 | ✅ 已覆盖 | `uniqueColumnNamesStillDecodeCorrectly` |

> 说明：全部 **182 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
>
> 变异验证（#559）：M1 将 `loadSchemas` 的写目标还原为 `databasesByConfig[config.id] = result` → `loadSchemasDoesNotOverwriteDatabaseCache`、`loadSchemasPopulatesSchemaCache` 转红（数据库缓存被 schema 覆盖、schema 缓存恒空）；M2 删除 `loadSchemas` 的 `schemasByConfig[config.id] = result` 写入 → `loadSchemasPopulatesSchemaCache` 转红（schema 缓存恒空）；M3 将 `loadDatabases` 的写目标改为 `schemasByConfig[config.id] = result` → `loadDatabasesPopulatesDatabaseCacheOnly`、`databaseCacheHitDoesNotRequeryAfterSchemaLoad`、`loadSchemasDoesNotOverwriteDatabaseCache` 转红（数据库缓存写错位置且缓存失效重新查询）。三处变异均单独施加并确认转红后还原，最终 103 条全绿。
>
> 变异验证（#560 / #561）：当前 dev 的 `stageDropIndex`、`stageRename` 均已先按名 `removeAll` 旧条目再追加，重复暂存天然收敛为单条 DDL，两 issue 报告的重复语句在现版本不可复现（前提已过时）。为锁定该不变量补充 6 条回归用例并验证鉴别力：M1 将 `stageDropIndex` 的去重判定 `existing.name == index.name` 改为 `false`（禁用索引删除去重）→ `repeatedIndexDropStagesOnce` 转红（同一索引生成两条 DROP INDEX）；M2 将 `stageRename` 的去重判定 `oldName == column.name` 改为 `false`（禁用重命名去重）→ `repeatedRenameFoldsToSingleStatement` 转红（同一原列生成两条 RENAME）。两处变异均单独施加并确认转红后还原，最终 109 条全绿。
>
> 变异验证（#558）：`DatabaseViewModel.connect` 原先把新 `config.id` 传给 `schemaCache.invalidate`，切换连接时清掉新连接缓存、留下旧连接缓存。修复为 `if let previousConfigId { schemaCache.invalidate(configId: previousConfigId) }`。M1 将失效目标还原为 `config.id`（原 bug）→ `switchInvalidatesPreviousObjectCache` 转红（旧连接 A 的对象缓存残留）；M2 删除失效调用（`_ = previousConfigId`）→ `switchInvalidatesPreviousDatabaseAndSchemaCache` 转红（旧连接 A 的数据库/schema 缓存残留）；M3 给失效加上 `previousConfigId != config.id` 守卫（跳过同配置重连）→ `reconnectSameConfigRefreshesCache` 转红（重连同一配置后旧数据库缓存未被清）。三处变异均单独施加并确认转红后还原，最终 113 条全绿。
>
> 变异验证（#273）：`RedisConnection.init` 原先恒用 `NWConnection(..., using: .tcp)`，`RedisDriver.connect` 丢弃 `config.sslOption`，即便选择 TLS 也明文发送 AUTH。修复为按 `RedisTransportPlan.make` + `RedisTransportSecurity.makeParameters` 构造传输层。M1 令 `makeParameters` 恒返回 `.tcp`（传输层忽略 TLS，原 bug）→ `tlsPlansProduceTLSParameters` 转红（4 个 TLS 模式都拿不到 TLS 协议），5 条计划映射与明文用例仍绿；M2 令 `RedisTransportPlan.make` 恒返回明文计划（决策层忽略 sslOption）→ `requireEnablesTLSWithoutFallback`、`verifyCAEnablesTLSWithCAOnlyVerification`、`verifyFullEnablesTLSWithFullVerification`、`preferEnablesTLSWithPlaintextFallback`、`tlsPlansProduceTLSParameters` 转红，disable/nil 与明文用例仍绿。两处变异均单独施加并确认转红后还原，最终 125 条全绿。
>
> 变异验证（#582）：`sqlLiteral` 原先对字符串只把 `'` 替换成 `''`，MySQL 默认开启反斜杠转义，用户输入的 `\n`/`\t` 被静默改写成控制字符。修复为按方言转义：MySQL 先把 `\` 翻倍再转义单引号，SQLite/PostgreSQL 保持只转义单引号。M1 禁用 MySQL 反斜杠转义分支（`if dialect == .mysql && false`）→ `mysqlStringEscapesBackslash`、`mysqlStringEscapesQuoteAndBackslash`、`mysqlUpdateEscapesBackslash`、`mysqlInsertEscapesBackslash`、`mysqlDeleteEscapesBackslashInPrimaryKey` 转红，`standardDialectsKeepBackslashLiteral` 仍绿。变异施加并确认转红后还原，最终 131 条全绿。
>
> 变异验证（#554）：`parseEditedCellValue` 原先对所有列统一 trim、把空串/`NULL` 映射成 SQL NULL、并推断 Int/Double/Bool，TEXT 列的合法内容被静默改写。修复为按列声明类型分流：文本类列（`isTextColumnType`）原样返回 `.string(text)`，其余列沿用推断；编辑提交入口改调 `TableChangeManager.parseEditedValue(_:column:)` 从 schema 取类型。M1 禁用文本分支（`if false && isTextColumnType(columnType)`）→ `textColumnPreservesPaddedWhitespace`、`textColumnPreservesLiteralNULL`、`textColumnPreservesLeadingZeros`、`textColumnPreservesEmptyString`、`textColumnUpdateGeneratesStringLiteral`、`textTypeVariantsPreserveRawString` 转红，`numericAndBooleanColumnsStillInferTypes`、`unknownColumnTypeFallsBackToInference` 仍绿。变异施加并确认转红后还原，最终 139 条全绿。
>
> 变异验证（#568）：UPDATE/DELETE 的 WHERE 原先对每个主键值都生成 `pk = 字面量`，NULL 主键变成 `pk = NULL`（SQL 里永不成立），命中 0 行却报保存成功并清空暂存。修复为 `primaryKeyCondition`：NULL 用 `IS NULL`、非 NULL 用 `=`；并在 `saveChanges` 校验行级写入（`isRowTargetingWrite`）的影响行数，命中 0 行回滚报错。M1 把 NULL 分支还原为 `= sqlLiteral(...)`（原 bug）→ `nullPrimaryKeyUpdateUsesIsNull`、`nullPrimaryKeyDeleteUsesIsNull`、`compositePrimaryKeyMixesNullAndEquals`、`nullPrimaryKeyUpdateActuallyModifiesRow`、`nullPrimaryKeyDeleteActuallyRemovesRow` 转红（端到端实测影响 0 行），非 NULL/守卫/判定用例仍绿；M2 删除 `saveChanges` 的影响行数守卫（还原 `_ = try await tx.execute`）→ `saveRollsBackWhenRowWriteAffectsNoRows` 转红（errorMessage 为空、暂存被清空、事务提交而非回滚），其余 8 条仍绿。两处变异均单独施加并确认转红后还原，最终 148 条全绿。
>
> 变异验证（#567）：`sqlLiteral(for:dialect:)` 的 `.data` 分支原先恒返回 `"NULL"`，BLOB 主键行的 UPDATE/DELETE 生成 `WHERE pk = NULL`（SQL 里永不成立），命中 0 行，编辑/删除静默失败。修复为按方言内联二进制字面量：SQLite/MySQL `X'…'`、PostgreSQL `decode('…','hex')`（BLOB 单元格编辑本身仍只读，见 #281）。M1 把 `.data` 分支还原为 `return "NULL"`（原 bug）→ 全部 7 条 BLOB 主键用例转红（端到端实测影响 0 行），#281 只读（2 条）与 #555 行标识（1 条）用例仍绿。变异施加并确认转红后还原，最终 155 条全绿。
>
> 变异验证（#565）：`refreshTableRowCount` 写回前校验 `openTableObject?.id == table.id` 与连接代次的修复已在 dev（commit edb8edfec），但此前没有 COUNT 竞态回归用例。补充 2 条用门闩构造「旧表 COUNT 晚到」的用例锁定该不变量。M1 删除写回前的 `openTableObject?.id == table.id` 校验（仅留连接代次）→ `staleCountFromPreviousTableDoesNotPolluteNewTable` 转红（A 的 999 覆盖 B 的 20），`currentTableCountIsWritten` 仍绿。变异施加并确认转红后还原，最终 157 条全绿。
>
> 变异验证（#583）：`saveSchemaChanges` 原先应用 DDL 后因 `changeManager?.hasChanges == true` 跳过重建数据变更管理器，使其继续持有旧列快照，重命名/删除被编辑引用的列后保存数据编辑生成 `UPDATE ... SET "name"` 报 `no such column`。修复为应用 DDL 前用 `referencedColumnNames` 与暂存结构变更的受影响列求交，相交则报错阻止。M1 删除该冲突守卫（直接进入 getConnection 执行 DDL）→ `renameOfColumnWithPendingEditIsBlocked`、`dropOfColumnWithPendingEditIsBlocked` 转红（tableSchemaError 为空、结构变更被应用、探针报 no such column: name），`referencedColumnNamesCollectsUpdateInsertDeleteColumns`、`renameOfUnreferencedColumnProceedsAndPreservesEdit`、`renameWithNoPendingDataEditProceeds` 仍绿。变异施加并确认转红后还原，最终 162 条全绿。
>
> 变异验证（#569）：`DatabaseConnectionStore.saveConfigs` 原先调用吞错的 `keychain.set`，无论密码是否写入成功都把脱敏配置落盘，表单随后无条件关闭；Keychain 写入失败（如锁定的 `errSecInteractionNotAllowed`）被静默忽略，重启后凭据无法恢复且界面无提示。修复为先完成全部 `setReportingErrors` 写入（失败抛出 `KeychainStoreError`）、最后才写 `UserDefaults`，并把 `addConfig`/`updateConfig`/`removeConfig` 改为 `throws`、持久化成功才更新内存列表。M1 把 `try keychain.setReportingErrors(...)` 还原为吞错的 `keychain.set(...)`（原 bug）→ `saveConfigsPropagatesKeychainWriteFailureAndDoesNotPersist`、`saveConfigsFailureKeepsPreviouslySavedConfigs`、`addConfigPropagatesKeychainFailureAndKeepsConfigsUnchanged`、`updateConfigPropagatesKeychainFailureAndKeepsOriginal` 转红（不抛错且配置被落盘/内存列表被更新），`saveConfigsSuccessSanitizesPasswordAndStoresInKeychain`、`loadConfigsRestoresPasswordFromKeychain`、`addConfigSuccessAppendsAndPersists` 仍绿。变异施加并确认转红后还原，最终 169 条全绿。
>
> 变异验证（#1254）：`MainView.toolbar` 原先在每次 body 求值时同步 `SQLStatementParser.split(viewModel.queryText).count`，普通编辑与无关的 ViewModel 发布都在主线程重复整段词法解析。修复为 `StatementCountCache` 按文本 memo + `queryText.didSet → refreshStatementCount()` 更新存储值 `statementCount`（仅计数变化才发布），工具栏改读 O(1) 的 `viewModel.statementCount`。M1 删除缓存的 memo 命中分支（每次都 `parseCount += 1` 并重新 `split`）→ `repeatedSameTextDoesNotReparse` 转红（同文本三次调用 parseCount 变 3），其余缓存/VM 用例仍绿；M2 删除 `queryText` 的 `didSet { refreshStatementCount() }`（计数不再随文本更新）→ `statementCountTracksQueryTextChanges`、`unrelatedPublicationDoesNotChangeStatementCount`、`resettingSameQueryTextKeepsCount` 转红（statementCount 停在 init seeding 值不跟随编辑），`statementCountSeededOnInit` 仍绿。两处变异均单独施加并确认转红后还原，最终 178 条全绿。
>
> 变异验证（#585）：`MySQLConnection.query` 原先对每个 `columnDefinitions` 调用 mysql-nio 的 `row.column(colDef.name)` 取值，而该方法按名字返回首个匹配列，重复列名（`SELECT a.id, b.id`、JOIN）时后面的同名列错显首列的值。修复为 `decodeRow` 按 `columnDefinitions` 与 `values` 的位置对应逐列构造 `MySQLData`。M1 把 `decodeRow` 的取值还原为按名字 `row.column(colDef.name) ?? MySQLData(...)`（原 bug）→ `duplicateColumnNamesKeepPositionalValues`、`joinLikeDuplicateNamesAcrossThreeColumnsDecodeByPosition`、`duplicateColumnNameWithNullSecondValueDecodesPositionally` 转红（同名列都拿到首列值、NULL 列被回填首列值），`uniqueColumnNamesStillDecodeCorrectly` 仍绿（唯一列名不受影响）。变异施加并确认转红后还原，最终 182 条全绿。

## 覆盖率统计

- P0: 已覆盖 92 / 92
- P1: 已覆盖 87 / 87
- P2: 已覆盖 3 / 3
- **合计: 182 / 182**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（92 条）
- **P1**: 其余功能性用例（87 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 182 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
