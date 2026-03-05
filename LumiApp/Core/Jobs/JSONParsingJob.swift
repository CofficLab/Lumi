import Foundation
import OSLog

/// JSON 解析任务
///
/// 负责在后台执行 JSON 数据解析，避免阻塞主线程
/// 适用于解析大型 JSON 数据或工具调用参数
struct JSONParsingJob {
    /// 日志标识 emoji
    nonisolated static let emoji = "📋"
    /// 是否输出详细日志
    nonisolated static let verbose = false
}

// MARK: - 任务参数

extension JSONParsingJob {
    /// 任务输入参数
    struct Input {
        /// 待解析的 JSON 字符串
        let jsonString: String
        /// 期望的输出类型（用于泛型解析）
        let targetType: TargetType
    }

    /// 目标类型枚举
    enum TargetType {
        case dictionary
        case array
        case any
    }

    /// 任务输出结果
    enum Output {
        case dictionary([String: Any])
        case array([Any])
        case any(Any)
        case parsingError(String)
    }
}

// MARK: - 任务执行

extension JSONParsingJob {
    /// 执行 JSON 解析任务
    ///
    /// 此方法在后台线程运行，不会阻塞 UI
    ///
    /// - Parameter input: 任务输入参数
    /// - Returns: 解析后的数据
    static func run(_ input: Input) async -> Output {
        if verbose {
            os_log("\(emoji) 开始执行 JSON 解析任务")
        }

        guard let data = input.jsonString.data(using: .utf8) else {
            os_log(.error, "\(emoji) 无法将字符串转换为 Data")
            return .parsingError("无法将字符串转换为 Data")
        }

        do {
            let result = try JSONSerialization.jsonObject(with: data, options: [])

            switch input.targetType {
            case .dictionary:
                if let dict = result as? [String: Any] {
                    if verbose {
                        os_log("\(emoji) JSON 解析成功：字典，\(dict.count) 个键")
                    }
                    return .dictionary(dict)
                } else {
                    return .parsingError("预期字典但得到其他类型")
                }

            case .array:
                if let array = result as? [Any] {
                    if verbose {
                        os_log("\(emoji) JSON 解析成功：数组，\(array.count) 个元素")
                    }
                    return .array(array)
                } else {
                    return .parsingError("预期数组但得到其他类型")
                }

            case .any:
                if verbose {
                    os_log("\(emoji) JSON 解析成功：任意类型")
                }
                return .any(result)
            }

        } catch {
            os_log(.error, "\(emoji) JSON 解析失败：\(error.localizedDescription)")
            return .parsingError(error.localizedDescription)
        }
    }

    /// 便捷方法：解析为字典
    ///
    /// - Parameter jsonString: JSON 字符串
    /// - Returns: 解析后的字典，失败返回空字典
    static func parseToDictionary(_ jsonString: String) async -> [String: Any] {
        let input = Input(jsonString: jsonString, targetType: .dictionary)
        let output = await run(input)

        if case .dictionary(let dict) = output {
            return dict
        }
        return [:]
    }

    /// 便捷方法：解析为 AnySendable
    ///
    /// - Parameter jsonString: JSON 字符串
    /// - Returns: 解析后的 AnySendable 字典
    static func parseToSendable(_ jsonString: String) async -> [String: AnySendable] {
        let dict = await parseToDictionary(jsonString)
        return dict.mapValues { AnySendable(value: $0) }
    }
}

// MARK: - 工具调用参数解析专用方法

extension JSONParsingJob {
    /// 解析工具调用参数
    ///
    /// 这是专门为工具调用设计的便捷方法
    ///
    /// - Parameter argumentsString: 工具调用参数字符串
    /// - Returns: 解析后的参数字典
    static func parseToolArguments(_ argumentsString: String) async -> [String: Any] {
        if argumentsString.isEmpty {
            return [:]
        }

        let input = Input(jsonString: argumentsString, targetType: .dictionary)
        let output = await run(input)

        if case .dictionary(let dict) = output {
            return dict
        }

        os_log(.error, "\(emoji) 工具参数解析失败，返回空字典")
        return [:]
    }

    /// 解析工具调用参数为 AnySendable
    ///
    /// - Parameter argumentsString: 工具调用参数字符串
    /// - Returns: 解析后的 AnySendable 参数字典
    static func parseToolArgumentsToSendable(_ argumentsString: String) async -> [String: AnySendable] {
        let dict = await parseToolArguments(argumentsString)
        return dict.mapValues { AnySendable(value: $0) }
    }
}
