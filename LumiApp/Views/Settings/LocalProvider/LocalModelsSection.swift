import Foundation

/// 本地模型按系列分组，用于设置页展示
struct LocalModelsSection: Identifiable {
    let seriesName: String
    let models: [LocalModelInfo]
    var id: String { seriesName }
}
