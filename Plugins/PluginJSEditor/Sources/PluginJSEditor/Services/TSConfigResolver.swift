import Foundation
import SuperLogKit

/// 解析 tsconfig.json / jsconfig.json，提取路径映射和编译选项
public struct TSConfigResolver: SuperLog {
    public nonisolated static let emoji = "⚙️"

    /// 从指定目录解析 tsconfig.json（不存在则尝试 jsconfig.json）
    public static func resolve(projectPath: String) -> TSProjectConfig? {
        let tsconfigURL = URL(fileURLWithPath: projectPath).appendingPathComponent("tsconfig.json")
        let jsconfigURL = URL(fileURLWithPath: projectPath).appendingPathComponent("jsconfig.json")

        let targetURL: URL
        if FileManager.default.fileExists(atPath: tsconfigURL.path) {
            targetURL = tsconfigURL
        } else if FileManager.default.fileExists(atPath: jsconfigURL.path) {
            targetURL = jsconfigURL
        } else {
            return nil
        }

        return parse(fileURL: targetURL)
    }

    /// 解析指定的 tsconfig/jsconfig 文件
    public static func parse(fileURL: URL) -> TSProjectConfig? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let jsonData = dataWithoutJSONCExtras(data) ?? data
            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            guard let json else { return nil }

            let compilerOptions = json["compilerOptions"] as? [String: Any] ?? [:]

            let baseURL = compilerOptions["baseUrl"] as? String
            let paths = compilerOptions["paths"] as? [String: [String]] ?? [:]
            let outDir = compilerOptions["outDir"] as? String
            let rootDir = compilerOptions["rootDir"] as? String
            let jsx = compilerOptions["jsx"] as? String
            let strict = compilerOptions["strict"] as? Bool
            let target = compilerOptions["target"] as? String
            let module = compilerOptions["module"] as? String
            let moduleResolution = compilerOptions["moduleResolution"] as? String

            return TSProjectConfig(
                baseURL: baseURL,
                paths: paths,
                outDir: outDir,
                rootDir: rootDir,
                jsx: jsx,
                strict: strict,
                target: target,
                module: module,
                moduleResolution: moduleResolution
            )
        } catch {
            return nil
        }
    }

    private static func dataWithoutJSONCExtras(_ data: Data) -> Data? {
        guard let source = String(data: data, encoding: .utf8) else { return nil }
        let withoutComments = removeJSONCComments(from: source)
        let withoutTrailingCommas = removeTrailingCommas(from: withoutComments)
        return withoutTrailingCommas.data(using: .utf8)
    }

    private static func removeJSONCComments(from source: String) -> String {
        var result = ""
        var index = source.startIndex
        var isInString = false
        var isEscaping = false

        while index < source.endIndex {
            let character = source[index]

            if isInString {
                result.append(character)
                if isEscaping {
                    isEscaping = false
                } else if character == "\\" {
                    isEscaping = true
                } else if character == "\"" {
                    isInString = false
                }
                index = source.index(after: index)
                continue
            }

            if character == "\"" {
                isInString = true
                result.append(character)
                index = source.index(after: index)
                continue
            }

            if character == "/" {
                let next = source.index(after: index)
                if next < source.endIndex {
                    if source[next] == "/" {
                        index = source.index(after: next)
                        while index < source.endIndex, !source[index].isNewline {
                            index = source.index(after: index)
                        }
                        continue
                    }

                    if source[next] == "*" {
                        index = source.index(after: next)
                        while index < source.endIndex {
                            let current = source[index]
                            let following = source.index(after: index)
                            if current == "*", following < source.endIndex, source[following] == "/" {
                                index = source.index(after: following)
                                break
                            }
                            result.append(current.isNewline ? current : " ")
                            index = following
                        }
                        continue
                    }
                }
            }

            result.append(character)
            index = source.index(after: index)
        }

        return result
    }

    private static func removeTrailingCommas(from source: String) -> String {
        var result = ""
        var index = source.startIndex
        var isInString = false
        var isEscaping = false

        while index < source.endIndex {
            let character = source[index]

            if isInString {
                result.append(character)
                if isEscaping {
                    isEscaping = false
                } else if character == "\\" {
                    isEscaping = true
                } else if character == "\"" {
                    isInString = false
                }
                index = source.index(after: index)
                continue
            }

            if character == "\"" {
                isInString = true
                result.append(character)
                index = source.index(after: index)
                continue
            }

            if character == "," {
                var lookahead = source.index(after: index)
                while lookahead < source.endIndex, source[lookahead].isWhitespace {
                    lookahead = source.index(after: lookahead)
                }
                if lookahead < source.endIndex, (source[lookahead] == "}" || source[lookahead] == "]") {
                    index = source.index(after: index)
                    continue
                }
            }

            result.append(character)
            index = source.index(after: index)
        }

        return result
    }
}
