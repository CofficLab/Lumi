import SwiftUI

/// Memory Plugin 设置视图
///
/// 在插件设置面板中显示记忆系统的配置选项。
struct MemorySettingsView: View {
    @State private var verboseLogging: Bool = MemoryPluginLocalStore.shared.isVerbose
    @State private var maxRelevantMemories: Int = MemoryPluginLocalStore.shared.maxRelevantMemories
    @State private var staleThresholdDays: Int = MemoryPluginLocalStore.shared.staleThresholdDays
    @State private var halfLifeDays: Double = MemoryPluginLocalStore.shared.halfLifeDays
    @State private var injectGlobalIndex: Bool = MemoryPluginLocalStore.shared.shouldInjectGlobalIndex
    @State private var injectProjectIndex: Bool = MemoryPluginLocalStore.shared.shouldInjectProjectIndex

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            Text("记忆设置")
                .font(.headline)

            Divider()

            // 注入选项
            VStack(alignment: .leading, spacing: 12) {
                Text("注入选项")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Toggle("注入全局记忆索引", isOn: $injectGlobalIndex)
                    .onChange(of: injectGlobalIndex) { _, newValue in
                        MemoryPluginLocalStore.shared.set(newValue, forKey: .injectGlobalIndex)
                    }

                Toggle("注入项目记忆索引", isOn: $injectProjectIndex)
                    .onChange(of: injectProjectIndex) { _, newValue in
                        MemoryPluginLocalStore.shared.set(newValue, forKey: .injectProjectIndex)
                    }

                Text("控制哪些记忆会被注入到每次对话的系统提示词中。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // 检索选项
            VStack(alignment: .leading, spacing: 12) {
                Text("检索选项")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Stepper(
                    "最大相关记忆数: \(maxRelevantMemories)",
                    value: $maxRelevantMemories,
                    in: 1...10
                )
                .onChange(of: maxRelevantMemories) { _, newValue in
                    MemoryPluginLocalStore.shared.set(newValue, forKey: .maxRelevantMemories)
                }

                Stepper(
                    "记忆过期阈值: \(staleThresholdDays) 天",
                    value: $staleThresholdDays,
                    in: 1...90
                )
                .onChange(of: staleThresholdDays) { _, newValue in
                    MemoryPluginLocalStore.shared.set(newValue, forKey: .staleThresholdDays)
                }

                Stepper(
                    "时效衰减半衰期: \(String(format: "%.0f", halfLifeDays)) 天",
                    value: $halfLifeDays,
                    in: 7...180,
                    step: 7
                )
                .onChange(of: halfLifeDays) { _, newValue in
                    MemoryPluginLocalStore.shared.set(newValue, forKey: .halfLifeDays)
                }

                Text("半衰期控制记忆随时间衰减的速度，值越大旧记忆保留权重越高。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // 调试
            VStack(alignment: .leading, spacing: 12) {
                Text("调试")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Toggle("详细日志", isOn: $verboseLogging)
                    .onChange(of: verboseLogging) { _, newValue in
                        MemoryPluginLocalStore.shared.set(newValue, forKey: .verboseLogging)
                    }

                Text("开启后将在控制台输出记忆加载和注入的详细日志。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // 说明
            VStack(alignment: .leading, spacing: 4) {
                Text("说明")
                    .font(.subheadline)
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 2) {
                    Text("• 记忆存储在本地文件系统中，支持手动编辑")
                    Text("• 记忆类型：user / feedback / project / reference")
                    Text("• 使用 save_memory / recall_memory 工具管理记忆")
                    Text("• 记忆是时间点快照，过期记忆会自动标注警告")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
