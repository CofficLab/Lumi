import Foundation
import SwiftUI

// MARK: - 全局 Alert 函数

/// 显示信息提示
/// - Parameters:
///   - title: 提示标题
///   - subtitle: 可选的副标题
///   - duration: 显示时长（默认3秒）
public func alert_info(_ title: String, subtitle: String? = nil, duration: TimeInterval = 3.0) {
    MagicMessageProvider.shared.info(title, subtitle: subtitle, duration: duration)
}

/// 显示成功提示
/// - Parameters:
///   - title: 提示标题
///   - subtitle: 可选的副标题
///   - duration: 显示时长（默认3秒）
public func alert_success(_ title: String, subtitle: String? = nil, duration: TimeInterval = 3.0) {
    MagicMessageProvider.shared.success(title, subtitle: subtitle, duration: duration)
}

/// 显示警告提示
/// - Parameters:
///   - title: 提示标题
///   - subtitle: 可选的副标题
///   - duration: 显示时长（默认4秒）
public func alert_warning(_ title: String, subtitle: String? = nil, duration: TimeInterval = 4.0) {
    MagicMessageProvider.shared.warning(title, subtitle: subtitle, duration: duration)
}

/// 显示错误提示（文本）
/// - Parameters:
///   - title: 错误标题
///   - subtitle: 可选的副标题
///   - duration: 显示时长（默认0，不自动消失）
///   - autoDismiss: 是否自动消失（默认false）
public func alert_error(_ title: String, subtitle: String? = nil, duration: TimeInterval = 0, autoDismiss: Bool = false) {
    MagicMessageProvider.shared.error(title, subtitle: subtitle, duration: duration, autoDismiss: autoDismiss)
}

/// 显示错误提示（Error 对象）
/// - Parameters:
///   - error: 错误对象
///   - title: 可选的标题，如果不提供则使用"错误"
///   - duration: 显示时长（默认0，不自动消失）
///   - autoDismiss: 是否自动消失（默认false）
public func alert_error(_ error: Error, title: String? = nil, duration: TimeInterval = 0, autoDismiss: Bool = false) {
    MagicMessageProvider.shared.error(error, title: title, duration: duration, autoDismiss: autoDismiss)
}

/// 显示加载中提示
/// - Parameters:
///   - title: 提示标题
///   - subtitle: 可选的副标题
public func alert_loading(_ title: String, subtitle: String? = nil) {
    MagicMessageProvider.shared.loading(title, subtitle: subtitle)
}

/// 隐藏加载中提示
public func alert_dismiss_loading() {
    MagicMessageProvider.shared.dismissLoading()
}

/// 隐藏所有提示
public func alert_dismiss_all() {
    MagicMessageProvider.shared.dismissAll()
}
