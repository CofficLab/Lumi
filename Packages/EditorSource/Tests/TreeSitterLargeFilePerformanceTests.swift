import XCTest
@testable import EditorSource
@testable import EditorTextView

/// Tree-sitter 大文件性能测试 - 模拟大文件的高亮解析性能
/// 测量 tree-sitter 初始化和高亮查询的耗时
class TreeSitterLargeFilePerformanceTests: XCTestCase {
    
    // MARK: - Test Data Generation
    
    /// 生成模拟的代码文件内容（更接近真实代码结构）
    /// - Parameter lines: 行数
    /// - Returns: 模拟的代码文本内容
    private func generateCodeContent(lines: Int) -> String {
        var content = ""
        content.reserveCapacity(lines * 80)
        
        for i in 0..<lines {
            if i % 10 == 0 {
                content += "func testFunction\(i)() {\n"
                content += "    let value = \(i)\n"
                content += "    print(\"Testing function \(i)\")\n"
                content += "    if value > 0 {\n"
                content += "        return value * 2\n"
                content += "    }\n"
                content += "}\n\n"
            } else {
                content += "// Line \(i): Some comment or code\n"
            }
        }
        
        return content
    }
    
    /// 生成不同规模的测试数据
    private enum TestScale {
        case small   // ~100KB
        case medium  // ~500KB
        case large   // ~5MB
        
        var lineCount: Int {
            switch self {
            case .small:  return 1_000
            case .medium: return 5_000
            case .large:  return 50_000
            }
        }
        
        var label: String {
            switch self {
            case .small:  return "Small (~100KB)"
            case .medium: return "Medium (~500KB)"
            case .large:  return "Large (~5MB)"
            }
        }
    }
    
    // MARK: - Phase 1: Tree-sitter 初始化测试
    
    /// 测试 Tree-sitter 状态初始化性能
    /// 测量创建 TreeSitterState 并解析整个文档的耗时
    func testTreeSitterStateInitialization() throws {
        let scales: [TestScale] = [.small, .medium, .large]
        
        for scale in scales {
            let content = generateCodeContent(lines: scale.lineCount)
            let textView = TextView(
                string: content,
                wrapLines: false,
                isEditable: false,
                isSelectable: true
            )
            
            measure(description: "TreeSitterState init \(scale.label)") {
                let client = TreeSitterClient()
                // 强制同步操作以便准确测量
                client.forceSyncOperation = true
                client.setUp(textView: textView, codeLanguage: .swift)
            }
        }
    }
    
    // MARK: - Phase 2: 高亮查询性能测试
    
    /// 测试单次高亮查询性能
    /// 测量对指定范围执行语法高亮查询的耗时
    func testHighlightQueryPerformance() throws {
        let scale = TestScale.medium
        let content = generateCodeContent(lines: scale.lineCount)
        let textView = TextView(
            string: content,
            wrapLines: false,
            isEditable: false,
            isSelectable: true
        )
        
        let client = TreeSitterClient()
        client.setUp(textView: textView, codeLanguage: .swift)
        
        // 等待初始化完成
        let setupExpectation = XCTestExpectation(description: "Setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 2.0)
        
        // 测试不同范围的高亮查询
        let ranges = [
            NSRange(location: 0, length: 1000),           // 小范围
            NSRange(location: 0, length: 10000),          // 中等范围
            NSRange(location: 0, length: content.count)   // 全文件
        ]
        
        for (index, range) in ranges.enumerated() {
            measure(description: "Highlight query range \(index) (\(range.length) chars)") {
                let expectation = XCTestExpectation(description: "Highlight query")
                
                client.queryHighlightsFor(textView: textView, range: range) { result in
                    switch result {
                    case .success(let highlights):
                        print("  ✓ Got \(highlights.count) highlights")
                    case .failure(let error):
                        XCTFail("Highlight query failed: \(error)")
                    }
                    expectation.fulfill()
                }
                
                wait(for: [expectation], timeout: 5.0)
            }
        }
    }
    
    // MARK: - Phase 3: 编辑后重新解析性能测试
    
    /// 测试编辑后的增量解析性能
    /// 测量在小范围编辑后，tree-sitter 重新解析的耗时
    func testIncrementalParseAfterEdit() throws {
        let scale = TestScale.medium
        let content = generateCodeContent(lines: scale.lineCount)
        let textView = TextView(
            string: content,
            wrapLines: false,
            isEditable: false,
            isSelectable: true
        )
        
        let client = TreeSitterClient()
        client.setUp(textView: textView, codeLanguage: .swift)
        
        // 等待初始化完成
        let setupExpectation = XCTestExpectation(description: "Setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 2.0)
        
        // 模拟多处编辑
        let editLocations = [
            NSRange(location: 100, length: 0),    // 插入
            NSRange(location: 5000, length: 10),  // 替换
            NSRange(location: 10000, length: 0),  // 插入
        ]
        
        for (index, range) in editLocations.enumerated() {
            measure(description: "Incremental parse edit \(index)") {
                let expectation = XCTestExpectation(description: "Apply edit")
                
                client.applyEdit(
                    textView: textView,
                    range: range,
                    delta: 20
                ) { result in
                    switch result {
                    case .success(let invalidatedRanges):
                        print("  ✓ Edit applied, invalidated \(invalidatedRanges.count) ranges")
                    case .failure(let error):
                        XCTFail("Apply edit failed: \(error)")
                    }
                    expectation.fulfill()
                }
                
                wait(for: [expectation], timeout: 2.0)
            }
        }
    }
    
    // MARK: - Phase 4: 全文件高亮性能测试
    
    /// 测试全文件高亮的性能
    /// 模拟打开文件后第一次完整高亮的场景
    func testFullFileHighlighting() throws {
        let scales: [TestScale] = [.small, .medium]
        
        for scale in scales {
            let content = generateCodeContent(lines: scale.lineCount)
            let textView = TextView(
                string: content,
                wrapLines: false,
                isEditable: false,
                isSelectable: true
            )
            
            let client = TreeSitterClient()
            client.setUp(textView: textView, codeLanguage: .swift)
            
            // 等待初始化完成
            let setupExpectation = XCTestExpectation(description: "Setup")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                setupExpectation.fulfill()
            }
            wait(for: [setupExpectation], timeout: 2.0)
            
            measure(description: "Full file highlight \(scale.label)") {
                let expectation = XCTestExpectation(description: "Full highlight")
                
                // 查询整个文件的高亮
                let fullRange = NSRange(location: 0, length: content.count)
                client.queryHighlightsFor(textView: textView, range: fullRange) { result in
                    switch result {
                    case .success(let highlights):
                        print("  ✓ Full file: \(highlights.count) highlights")
                    case .failure(let error):
                        XCTFail("Full highlight failed: \(error)")
                    }
                    expectation.fulfill()
                }
                
                wait(for: [expectation], timeout: 10.0)
            }
        }
    }
    
    // MARK: - Phase 5: 对比测试 - 不同语言
    
    /// 测试不同语言的解析性能差异
    func testDifferentLanguageParsing() throws {
        let scale = TestScale.medium
        
        let languages: [(EditorLanguageContext, String)] = [
            (.swift, "Swift"),
            (.plainText, "Plain Text")
        ]
        
        for (language, name) in languages {
            let content = generateCodeContent(lines: scale.lineCount)
            let textView = TextView(
                string: content,
                wrapLines: false,
                isEditable: false,
                isSelectable: true
            )
            
            measure(description: "Parse \(name) \(scale.label)") {
                let client = TreeSitterClient()
                client.setUp(textView: textView, codeLanguage: language)
                
                let expectation = XCTestExpectation(description: "Setup \(name)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    expectation.fulfill()
                }
                wait(for: [expectation], timeout: 1.0)
            }
        }
    }
}
