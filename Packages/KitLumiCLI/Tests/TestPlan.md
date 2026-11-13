# TestPlan — KitLumiCLI

## 包概述

KitLumiCLI `lumi` 命令行工具的安装包。负责挑选安装目录、生成脚本、写入磁盘与查询安装状态。

平台: macOS 14+
测试文件: 8 个，用例总数: 68

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `CLIInstallTarget`
- `CLIInstallOutcome`
- `CLIPathResolver`
- `CLIScriptBuilder`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **CLIEncodingConsistency**（4 条）：由 `scriptEncodingIsReversibleByApp`、`appEncodingIsReversibleByApp`、`scriptEncodingIsAcceptedByURLComponents` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CLIInstallTargetResolver**（9 条）：由 `prefersWritablePathDirectory`、`excludesNonWritablePathDirectory`、`excludesMissingPathDirectory` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CLIInstaller**（14 条）：由 `installCreatesExecutableScript`、`installReportsNotOnPath`、`installFailsForNonWritableTarget` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CLIPathResolver**（6 条）：由 `parsesPathEntries`、`parsesEmptyPath`、`resolvedPathContainsSystemDirectories` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CLIScriptBuilder**（13 条）：由 `scriptStartsWithShebang`、`defaultCommandNameIsLumi`、`usesExistingOpenProjectProtocol` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CLIScriptBuilderShellEscaping**（8 条）：由 `dollarSignPathResolvesVerbatim`、`backtickPathResolvesVerbatim`、`combinedSpecialCharsPathResolvesVerbatim` 等用例锁定；真实执行 /bin/sh，断言含 `$`、反引号、双引号、反斜杠、单引号、空格、非 ASCII 的安装路径原样解析（#142）。
- **CLIScriptBuilderURLEncoding**（6 条）：由 `newlineInPathIsPreserved`、`crlfInPathIsPreserved`、`multibyteWithNewlineRoundTrips` 等用例锁定；真实执行 /bin/sh 运行脚本的 `urlencode`，断言换行/回车逐字节编码为 %0A/%0D 并可被 App 还原（#143）。
- **CLIPathResolverShellOutput**（8 条）：由 `relativeDotPrefixKeepsAbsoluteEntries`、`emptyEntryPrefixKeepsAbsoluteEntries`、`rcNoiseBeforePathIsSkipped` 等用例锁定；直接驱动 `absolutePathEntries(fromShellOutput:)`，断言相对/空条目前缀的 PATH 行仍保留其后绝对目录、rc 噪声被跳过（#144）。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | CLIEncodingConsistency | 脚本编码可被 App 还原 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scriptEncodingIsReversibleByApp` |
| 2 | CLIEncodingConsistency | App 自身构造的 URL 可被自己解析回来 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appEncodingIsReversibleByApp` |
| 3 | CLIEncodingConsistency | 脚本产出的编码是合法的 URL query | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scriptEncodingIsAcceptedByURLComponents` |
| 4 | CLIEncodingConsistency | 脚本中的 perl 编码表达式与测试中的一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scriptUsesSameEncoderAsTest` |
| 5 | CLIInstallTargetResolver | PATH 中已存在且可写的目录排在最前 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `prefersWritablePathDirectory` |
| 6 | CLIInstallTargetResolver | 不可写的 PATH 目录被排除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `excludesNonWritablePathDirectory` |
| 7 | CLIInstallTargetResolver | PATH 中不存在的目录被排除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `excludesMissingPathDirectory` |
| 8 | CLIInstallTargetResolver | ~/.local/bin 始终作为兜底候选 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `alwaysOffersUserLocalBin` |
| 9 | CLIInstallTargetResolver | 没有 HOME 时不产生用户级候选 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `omitsUserTargetWithoutHome` |
| 10 | CLIInstallTargetResolver | bestTarget 优先返回已在 PATH 中的可写目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bestTargetPrefersOnPath` |
| 11 | CLIInstallTargetResolver | 重复的 PATH 条目只产生一个候选 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `deduplicatesPathEntries` |
| 12 | CLIInstallTargetResolver | scriptURL 指向目标目录下的命令名 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scriptURLPointsIntoDirectory` |
| 13 | CLIInstaller | 安装后脚本存在且可执行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installCreatesExecutableScript` |
| 14 | CLIInstaller | 安装到不在 PATH 中的目录时返回 installedButNotOnPath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installReportsNotOnPath` |
| 15 | CLIInstaller | 写入不可写目录时安装失败 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installFailsForNonWritableTarget` |
| 16 | CLIInstaller | 安装到不存在的目录时自动创建 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installCreatesMissingDirectory` |
| 17 | CLIInstaller | 未安装时状态为未安装 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusReportsNotInstalled` |
| 18 | CLIInstaller | 安装后状态能查到脚本路径 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusFindsInstalledScript` |
| 19 | CLIInstaller | 卸载后脚本被删除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `uninstallRemovesScript` |
| 20 | CLIInstaller | 未安装时卸载也算成功 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `uninstallSucceedsWhenNotInstalled` |
| 21 | CLIInstaller | 安装的脚本内容包含 LUMI_APP 与 open-project 协议 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installedScriptContentIsExpected` |
| 22 | CLIPathResolver | PATH 字符串按冒号拆分并去掉空项 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesPathEntries` |
| 23 | CLIPathResolver | 空 PATH 得到空列表 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `parsesEmptyPath` |
| 24 | CLIPathResolver | 解析出的用户 PATH 包含系统目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolvedPathContainsSystemDirectories` |
| 25 | CLIPathResolver | 解析用户 PATH 优先于进程 PATH | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolvedPathPrefersUserShellPath` |
| 26 | CLIPathResolver | SHELL 无效时回落到进程 PATH | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fallsBackToProcessPathWithInvalidShell` |
| 27 | CLIPathResolver | shell 解析不会挂起 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolutionTerminatesPromptly` |
| 28 | CLIScriptBuilder | 脚本以 shebang 开头且带执行权限语义 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scriptStartsWithShebang` |
| 29 | CLIScriptBuilder | 命令名默认为 lumi | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultCommandNameIsLumi` |
| 30 | CLIScriptBuilder | 脚本复用 Lumi 既有的 open-project 协议 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesExistingOpenProjectProtocol` |
| 31 | CLIScriptBuilder | 脚本显式用 open -g -a 指定 App | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesExplicitAppRouting` |
| 32 | CLIScriptBuilder | 脚本不修改用户的 shell 配置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotModifyShellConfiguration` |
| 33 | CLIScriptBuilder | 脚本优先使用 LUMI_APP 环境变量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `honorsAppPathEnvironmentVariable` |
| 34 | CLIScriptBuilder | 安装时记录的 App 路径被写入脚本 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `embedsRecordedAppPath` |
| 35 | CLIScriptBuilder | 未提供 App 路径时使用常见安装位置兜底 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToCommonInstallLocations` |
| 36 | CLIScriptBuilder | scheme 从 App 的 Info.plist 读取并有兜底值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readsSchemeFromInfoPlist` |
| 37 | CLIScriptBuilder | 生成的脚本通过 shell 语法检查 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `generatedScriptIsValidShell` |
| 38 | CLIInstallTargetResolver | PATH 中缺失的 `~/.local/bin` 仍作为可写兜底候选（**回归 #945**） | `HOME` 下 `.local/bin` 不存在，PATH 包含该路径 | 解析候选目录与 `bestTarget` | 候选包含该目录，`isOnPath` 与 `isWritable` 均为 true，`bestTarget` 返回它 | P1 | ✅ 已覆盖 | `missingUserPathDirectoryStillFallsBackToUserTarget` |
| 39 | CLIScriptBuilderShellEscaping | 含 `$` 的安装路径必须原样解析，不得被 shell 展开 | 临时目录下创建名为 `Dollar$LUMI_SUFFIX.app` 的真实目录 | 生成脚本，抽出 `find_lumi_app` 用 /bin/sh 执行（移除 LUMI_APP） | 原样返回该目录，`$LUMI_SUFFIX` 不被展开 | P0 | ✅ 已覆盖 | `dollarSignPathResolvesVerbatim` |
| 40 | CLIScriptBuilderShellEscaping | 含反引号的安装路径必须原样解析，不得触发命令替换 | 创建名为 ``Backtick`lumi_nx_cmd.app`` 的真实目录 | 生成脚本，抽出 `find_lumi_app` 用 /bin/sh 执行（移除 LUMI_APP） | 原样返回，反引号不触发命令替换 | P0 | ✅ 已覆盖 | `backtickPathResolvesVerbatim` |
| 41 | CLIScriptBuilderShellEscaping | 含双引号的安装路径必须原样解析，不得破坏引号边界 | 创建名为 `Quote"name.app` 的真实目录 | 生成脚本，抽出 `find_lumi_app` 用 /bin/sh 执行（移除 LUMI_APP） | 原样返回，双引号不破坏脚本引号边界 | P0 | ✅ 已覆盖 | `doubleQuotePathResolvesVerbatim` |
| 42 | CLIScriptBuilderShellEscaping | 含反斜杠的安装路径必须原样解析，不得被转义改写 | 创建名为 `Two\\back.app` 的真实目录 | 生成脚本，抽出 `find_lumi_app` 用 /bin/sh 执行（移除 LUMI_APP） | 原样返回，反斜杠不被转义改写 | P0 | ✅ 已覆盖 | `backslashPathResolvesVerbatim` |
| 43 | CLIScriptBuilderShellEscaping | 含单引号的安装路径原样解析（单引号转义回归） | 创建名为 `Single'quote.app` 的真实目录 | 生成脚本，抽出 `find_lumi_app` 用 /bin/sh 执行（移除 LUMI_APP） | 原样返回，单引号用 `'\''` 正确拼接 | P1 | ✅ 已覆盖 | `singleQuotePathResolvesVerbatim` |
| 44 | CLIScriptBuilderShellEscaping | 含空格的安装路径原样解析 | 创建名为 `Space name.app` 的真实目录 | 生成脚本，抽出 `find_lumi_app` 用 /bin/sh 执行（移除 LUMI_APP） | 原样返回含空格的路径 | P1 | ✅ 已覆盖 | `spacePathResolvesVerbatim` |
| 45 | CLIScriptBuilderShellEscaping | 含非 ASCII 字符的安装路径原样解析 | 创建名为 `中文应用.app` 的真实目录 | 生成脚本，抽出 `find_lumi_app` 用 /bin/sh 执行（移除 LUMI_APP） | 原样返回含中文的路径 | P1 | ✅ 已覆盖 | `nonASCIIPathResolvesVerbatim` |
| 46 | CLIScriptBuilderShellEscaping | 含全部特殊字符的安装路径必须原样解析，不得被 shell 改写 | 创建名为 ``Mix $v `lumi_nx` "q" \w 's' 中文.app`` 的真实目录 | 生成脚本，抽出 `find_lumi_app` 用 /bin/sh 执行（移除 LUMI_APP） | 原样返回，所有特殊字符均不被展开/改写 | P0 | ✅ 已覆盖 | `combinedSpecialCharsPathResolvesVerbatim` |
| 47 | CLIScriptBuilderURLEncoding | 含换行的目录名必须编码为 %0A，不得被 chomp 丢弃 | 路径 `/tmp/a\nb`（含真实换行） | 生成脚本，抽出 `urlencode` 用 /bin/sh 执行（路径作为 argv 传入） | 编码为 `%2Ftmp%2Fa%0Ab`，换行保留为 %0A | P0 | ✅ 已覆盖 | `newlineInPathIsPreserved` |
| 48 | CLIScriptBuilderURLEncoding | 含回车的目录名必须编码为 %0D | 路径 `/tmp/a\rb`（含真实回车） | 生成脚本，抽出 `urlencode` 用 /bin/sh 执行（路径作为 argv 传入） | 编码为 `%2Ftmp%2Fa%0Db` | P0 | ✅ 已覆盖 | `carriageReturnInPathIsPreserved` |
| 49 | CLIScriptBuilderURLEncoding | 含 CRLF 的目录名必须编码为 %0D%0A，不得只保留回车 | 路径 `/tmp/a\r\nb`（含 CRLF） | 生成脚本，抽出 `urlencode` 用 /bin/sh 执行（路径作为 argv 传入） | 编码为 `%2Ftmp%2Fa%0D%0Ab` | P0 | ✅ 已覆盖 | `crlfInPathIsPreserved` |
| 50 | CLIScriptBuilderURLEncoding | 含换行的路径经脚本编码后可被 App 原样还原 | 路径 `/tmp/a\nb` | 生成脚本，抽出 `urlencode` 用 /bin/sh 执行（路径作为 argv 传入） | 脚本编码后经 `URLComponents` 还原 == 原路径 | P1 | ✅ 已覆盖 | `newlinePathRoundTripsThroughApp` |
| 51 | CLIScriptBuilderURLEncoding | 多字节字符与换行混合的路径编码后可被 App 原样还原 | 路径 `/tmp/中文\n目录` | 生成脚本，抽出 `urlencode` 用 /bin/sh 执行（路径作为 argv 传入） | 编码含 %0A，且 App 还原 == 原路径 | P1 | ✅ 已覆盖 | `multibyteWithNewlineRoundTrips` |
| 52 | CLIScriptBuilderURLEncoding | 不含特殊字符的多字节路径编码保持不变（无回归） | 路径 `/tmp/中文目录` | 生成脚本，抽出 `urlencode` 用 /bin/sh 执行（路径作为 argv 传入） | 编码为 `%2Ftmp%2F%E4%B8%AD%E6%96%87%E7%9B%AE%E5%BD%95` | P1 | ✅ 已覆盖 | `plainMultibytePathIsUnchanged` |
| 53 | CLIPathResolverShellOutput | 以 . 开头的 PATH 行必须保留其后的绝对目录 | shell 输出 `.:/custom/bin:/usr/bin` | 调用 `absolutePathEntries(fromShellOutput:)` | 保留 `/custom/bin`、`/usr/bin`，相对条目 `.` 被忽略 | P0 | ✅ 已覆盖 | `relativeDotPrefixKeepsAbsoluteEntries` |
| 54 | CLIPathResolverShellOutput | 以相对目录开头的 PATH 行必须保留其后的绝对目录 | shell 输出 `bin:/custom/bin:/usr/bin` | 调用 `absolutePathEntries(fromShellOutput:)` | 保留 `/custom/bin`、`/usr/bin`，相对条目 `bin` 被忽略 | P0 | ✅ 已覆盖 | `relativeDirectoryPrefixKeepsAbsoluteEntries` |
| 55 | CLIPathResolverShellOutput | 以空条目开头的 PATH 行必须保留其后的绝对目录 | shell 输出 `:/custom/bin:/usr/bin` | 调用 `absolutePathEntries(fromShellOutput:)` | 保留 `/custom/bin`、`/usr/bin`，空条目被去掉 | P0 | ✅ 已覆盖 | `emptyEntryPrefixKeepsAbsoluteEntries` |
| 56 | CLIPathResolverShellOutput | PATH 前的 rc 噪声行被跳过，仍解析出绝对目录 | 输出含 rc 噪声行后跟 `.:/custom/bin:/usr/bin` | 调用 `absolutePathEntries(fromShellOutput:)` | 保留 `/custom/bin`、`/usr/bin`，rc 噪声行不被当作 PATH | P1 | ✅ 已覆盖 | `rcNoiseBeforePathIsSkipped` |
| 57 | CLIPathResolverShellOutput | 全绝对 PATH 行解析保持不变（无回归） | shell 输出 `/usr/bin:/bin` | 调用 `absolutePathEntries(fromShellOutput:)` | 返回 `/usr/bin`、`/bin`，顺序不变 | P1 | ✅ 已覆盖 | `absoluteOnlyPathUnchanged` |
| 58 | CLIPathResolverShellOutput | 全相对 PATH 行不产生绝对条目 | shell 输出 `.:./bin:foo` | 调用 `absolutePathEntries(fromShellOutput:)` | 返回空列表（无绝对条目） | P1 | ✅ 已覆盖 | `allRelativePathYieldsEmpty` |
| 59 | CLIPathResolverShellOutput | PATH 后的尾随噪声行被跳过 | 输出 `/usr/bin:/bin` 后跟尾随噪声行 | 调用 `absolutePathEntries(fromShellOutput:)` | 返回 `/usr/bin`、`/bin`，尾随噪声被跳过 | P1 | ✅ 已覆盖 | `trailingNoiseAfterPathIsSkipped` |
| 60 | CLIPathResolverShellOutput | 空输出得到空列表 | 空字符串输出 | 调用 `absolutePathEntries(fromShellOutput:)` | 返回空列表 | P2 | ✅ 已覆盖 | `emptyOutputYieldsEmpty` |
| 61 | CLIInstaller | 安装遇到同名第三方程序时拒绝覆盖，原内容不得丢失（**回归 #134**） | 临时目录下已有可执行 `lumi`，内容为第三方脚本 | 以该目录为 target 调用 `install` | 返回 `.failed`，脚本内容仍为原文且可执行 | P0 | ✅ 已覆盖 | `installPreservesUnrelatedExecutable` |
| 62 | CLIInstaller | 卸载不得删除同名第三方程序（**回归 #134**） | 临时目录下已有可执行 `lumi`（第三方内容） | 调用 `uninstall(pathEntries:)` | 返回 true，第三方文件仍存在且内容不变 | P0 | ✅ 已覆盖 | `uninstallPreservesUnrelatedExecutable` |
| 63 | CLIInstaller | 状态查询不把同名第三方程序当作已安装（**回归 #134**） | 临时目录下已有可执行 `lumi`（第三方内容） | 调用 `status(pathEntries:)` | `isInstalled` 为 false，`installedPath` 为 nil | P1 | ✅ 已覆盖 | `statusDoesNotReportUnrelatedExecutableAsInstalled` |
| 64 | CLIInstaller | 重复安装可更新已有的 Lumi 脚本（升级路径不被破坏） | 已安装 Lumi 脚本的目录 | 用新的 appPath 再次调用 `install` | 返回 `.installed`，脚本含新 appPath 且可执行 | P1 | ✅ 已覆盖 | `installUpdatesExistingLumiScript` |
| 65 | CLIInstaller | 旧版 Lumi 脚本仍被识别为已安装并可卸载（向后兼容） | 临时目录下写入只含旧版中文签名的可执行 `lumi` | 调用 `status` 与 `uninstall` | `isInstalled` 为 true，卸载后文件被删除 | P1 | ✅ 已覆盖 | `legacyLumiScriptIsStillRecognized` |
| 66 | CLIScriptBuilder | 生成的脚本带有归属标记 | — | 调用 `scriptContents()` | 内容包含 `ownershipMarker` | P1 | ✅ 已覆盖 | `scriptCarriesOwnershipMarker` |
| 67 | CLIScriptBuilder | 归属判定接受新标记与旧版签名 | — | 调用 `isLumiOwnedScriptContents` | 含新标记或旧版签名的内容均返回 true | P1 | ✅ 已覆盖 | `ownershipDetectionAcceptsLumiScripts` |
| 68 | CLIScriptBuilder | 归属判定不得把无关脚本认作 Lumi 安装 | — | 调用 `isLumiOwnedScriptContents` | 无关脚本与空字符串均返回 false | P0 | ✅ 已覆盖 | `ownershipDetectionRejectsUnrelatedScript` |

> 说明：全部 **68 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 16 / 16
- P1: 已覆盖 49 / 49
- P2: 已覆盖 3 / 3
- **合计: 68 / 68**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（16 条）
- **P1**: 其余功能性用例（49 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+
- 68 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitLumiCLI
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
