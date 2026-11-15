import Foundation

/// 缓存当前思维导图的布局结果。
///
/// 画布的平移/缩放只改变 scale/offset，地图本身不变；原先每次手势回调都重新
/// 跑完整布局（含文本测量）。这里按地图值相等性缓存：仅当结构/文本/折叠/布局
/// 方向等影响布局的状态变化时才重算，视口变换直接复用缓存（#1191）。
///
/// 以引用类型持有于 SwiftUI `@State`，body 内读取/更新其内部存储不会触发
/// `@State` 值变更那样的视图失效循环。
@MainActor
final class MindMapLayoutCache {
    private let compute: (MindMap) -> MindMapLayoutEngine.Result
    private var cachedMap: MindMap?
    private var cachedResult: MindMapLayoutEngine.Result?

    init(compute: @escaping (MindMap) -> MindMapLayoutEngine.Result = { MindMapLayoutEngine.layout($0) }) {
        self.compute = compute
    }

    func layout(for map: MindMap) -> MindMapLayoutEngine.Result {
        if let cachedMap, cachedMap == map, let cachedResult {
            return cachedResult
        }
        let result = compute(map)
        cachedMap = map
        cachedResult = result
        return result
    }
}