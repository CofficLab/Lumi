import SwiftUI

/// View 边框扩展
public extension View {
    /// 在顶部添加分隔线
    func borderTop() -> some View {
        overlay(alignment: .top) {
            AppDivider(.horizontal)
        }
    }
    
    /// 在底部添加分隔线
    func borderBottom() -> some View {
        overlay(alignment: .bottom) {
            AppDivider(.horizontal)
        }
    }
    
    /// 在左侧添加分隔线
    func borderLeading() -> some View {
        overlay(alignment: .leading) {
            AppDivider(.vertical)
        }
    }
    
    /// 在右侧添加分隔线
    func borderTrailing() -> some View {
        overlay(alignment: .trailing) {
            AppDivider(.vertical)
        }
    }
    
    /// 在水平方向（左右）添加分隔线
    func borderHorizontal() -> some View {
        overlay(alignment: .leading) {
            AppDivider(.vertical)
        }
        .overlay(alignment: .trailing) {
            AppDivider(.vertical)
        }
    }
    
    /// 在垂直方向（上下）添加分隔线
    func borderVertical() -> some View {
        overlay(alignment: .top) {
            AppDivider(.horizontal)
        }
        .overlay(alignment: .bottom) {
            AppDivider(.horizontal)
        }
    }
    
    /// 在四周添加分隔线
    func borderAll() -> some View {
        overlay(alignment: .top) {
            AppDivider(.horizontal)
        }
        .overlay(alignment: .bottom) {
            AppDivider(.horizontal)
        }
        .overlay(alignment: .leading) {
            AppDivider(.vertical)
        }
        .overlay(alignment: .trailing) {
            AppDivider(.vertical)
        }
    }
}
