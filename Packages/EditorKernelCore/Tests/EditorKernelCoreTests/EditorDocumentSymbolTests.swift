import Foundation
import Testing
import LanguageServerProtocol
@testable import EditorKernelCore

@MainActor
@Suite("EditorDocumentSymbolProviderCore Tests")
struct EditorDocumentSymbolProviderCoreTests {

    @Test
    func initializationWithRequestDocumentSymbols() async {
        let provider = EditorDocumentSymbolProviderCore(
            requestDocumentSymbols: { [] }
        )

        #expect(provider.symbols.isEmpty)
        #expect(provider.isLoading == false)
    }

    @Test
    func refreshSetsIsLoadingAndUpdatesSymbols() async {
        let testSymbols = [
            DocumentSymbol(
                name: "TestClass",
                detail: nil,
                kind: .class,
                deprecated: nil,
                range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 10, character: 0)),
                selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 10)),
                children: nil
            )
        ]

        let provider = EditorDocumentSymbolProviderCore(
            requestDocumentSymbols: { testSymbols }
        )

        provider.refresh()

        // Wait for async operation to complete
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(provider.symbols.count == 1)
        #expect(provider.symbols[0].name == "TestClass")
        #expect(provider.isLoading == false)
    }

    @Test
    func clearResetsState() async {
        let provider = EditorDocumentSymbolProviderCore(
            requestDocumentSymbols: { [] }
        )

        provider.clear()

        #expect(provider.symbols.isEmpty)
        #expect(provider.isLoading == false)
    }

    @Test
    func resetDoesNotClearSymbols() async {
        let testSymbols = [
            DocumentSymbol(
                name: "Test",
                detail: nil,
                kind: .function,
                deprecated: nil,
                range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 1, character: 0)),
                selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 5)),
                children: nil
            )
        ]

        let provider = EditorDocumentSymbolProviderCore(
            requestDocumentSymbols: { testSymbols }
        )

        provider.refresh()
        try? await Task.sleep(nanoseconds: 100_000_000)

        provider.reset()

        // reset() should not clear symbols
        #expect(provider.symbols.count == 1)
    }

    @Test
    func applySymbolsUpdatesSymbolsList() async {
        let provider = EditorDocumentSymbolProviderCore(
            requestDocumentSymbols: { [] }
        )

        let symbols = [
            EditorDocumentSymbolItem(
                id: "TestClass",
                name: "TestClass",
                detail: nil,
                kind: .class,
                range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 10, character: 0)),
                selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 10)),
                children: []
            )
        ]

        provider.applySymbols(symbols)

        #expect(provider.symbols.count == 1)
        #expect(provider.symbols[0].name == "TestClass")
    }

    @Test
    func activeItemsReturnsCorrectItems() async {
        let parentSymbol = EditorDocumentSymbolItem(
            id: "Parent",
            name: "Parent",
            detail: nil,
            kind: .class,
            range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 20, character: 0)),
            selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 10)),
            children: []
        )

        let provider = EditorDocumentSymbolProviderCore(
            requestDocumentSymbols: { [] }
        )
        provider.applySymbols([parentSymbol])

        let activeItems = provider.activeItems(for: 5)

        #expect(activeItems.count == 1)
        #expect(activeItems[0].name == "Parent")
    }

    @Test
    func activeItemsReturnsEmptyForOutOfRange() async {
        let symbol = EditorDocumentSymbolItem(
            id: "Test",
            name: "Test",
            detail: nil,
            kind: .function,
            range: LSPRange(start: Position(line: 5, character: 0), end: Position(line: 10, character: 0)),
            selectionRange: LSPRange(start: Position(line: 5, character: 0), end: Position(line: 5, character: 5)),
            children: []
        )

        let provider = EditorDocumentSymbolProviderCore(
            requestDocumentSymbols: { [] }
        )
        provider.applySymbols([symbol])

        let activeItems = provider.activeItems(for: 0)

        #expect(activeItems.isEmpty)
    }

    @Test
    func activePathIDsReturnsCorrectIDs() async {
        let symbol = EditorDocumentSymbolItem(
            id: "TestClass",
            name: "TestClass",
            detail: nil,
            kind: .class,
            range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 20, character: 0)),
            selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 10)),
            children: []
        )

        let provider = EditorDocumentSymbolProviderCore(
            requestDocumentSymbols: { [] }
        )
        provider.applySymbols([symbol])

        let pathIDs = provider.activePathIDs(for: 10)

        #expect(pathIDs.count == 1)
        #expect(pathIDs[0] == "TestClass")
    }

    @Test
    func activeAncestorIDsReturnsCorrectSet() async {
        let parent = EditorDocumentSymbolItem(
            id: "Parent",
            name: "Parent",
            detail: nil,
            kind: .class,
            range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 20, character: 0)),
            selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 10)),
            children: []
        )

        let provider = EditorDocumentSymbolProviderCore(
            requestDocumentSymbols: { [] }
        )
        provider.applySymbols([parent])

        let ancestorIDs = provider.activeAncestorIDs(for: 10)

        // For a single item, ancestors should be empty (dropLast)
        #expect(ancestorIDs.isEmpty)
    }

    @Test
    func handlesNestedSymbols() async {
        let childSymbol = DocumentSymbol(
            name: "ChildMethod",
            detail: nil,
            kind: .method,
            deprecated: nil,
            range: LSPRange(start: Position(line: 5, character: 0), end: Position(line: 10, character: 0)),
            selectionRange: LSPRange(start: Position(line: 5, character: 0), end: Position(line: 5, character: 15)),
            children: nil
        )

        let parentSymbol = DocumentSymbol(
            name: "ParentClass",
            detail: nil,
            kind: .class,
            deprecated: nil,
            range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 20, character: 0)),
            selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 15)),
            children: [childSymbol]
        )

        let provider = EditorDocumentSymbolProviderCore(
            requestDocumentSymbols: { [parentSymbol] }
        )

        provider.refresh()
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(provider.symbols.count == 1)
        #expect(provider.symbols[0].children.count == 1)
    }
}

@Suite("EditorDocumentSymbolItem Tests")
struct EditorDocumentSymbolItemTests {

    @Test
    func initializationFromDocumentSymbol() {
        let lspSymbol = DocumentSymbol(
            name: "TestClass",
            detail: "A test class",
            kind: .class,
            deprecated: nil,
            range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 10, character: 0)),
            selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 10)),
            children: nil
        )

        let item = EditorDocumentSymbolItem(symbol: lspSymbol)

        #expect(item.name == "TestClass")
        #expect(item.detail == "A test class")
        #expect(item.kind == .class)
        #expect(item.id == "TestClass")
        #expect(item.children.isEmpty)
    }

    @Test
    func initializationWithPath() {
        let lspSymbol = DocumentSymbol(
            name: "method",
            detail: nil,
            kind: .method,
            deprecated: nil,
            range: LSPRange(start: Position(line: 5, character: 0), end: Position(line: 10, character: 0)),
            selectionRange: LSPRange(start: Position(line: 5, character: 0), end: Position(line: 5, character: 10)),
            children: nil
        )

        let item = EditorDocumentSymbolItem(symbol: lspSymbol, path: ["TestClass"])

        #expect(item.id == "TestClass/method")
    }

    @Test
    func initializationWithChildren() {
        let childSymbol = DocumentSymbol(
            name: "childMethod",
            detail: nil,
            kind: .method,
            deprecated: nil,
            range: LSPRange(start: Position(line: 5, character: 0), end: Position(line: 8, character: 0)),
            selectionRange: LSPRange(start: Position(line: 5, character: 0), end: Position(line: 5, character: 15)),
            children: nil
        )

        let parentSymbol = DocumentSymbol(
            name: "ParentClass",
            detail: nil,
            kind: .class,
            deprecated: nil,
            range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 20, character: 0)),
            selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 15)),
            children: [childSymbol]
        )

        let item = EditorDocumentSymbolItem(symbol: parentSymbol)

        #expect(item.children.count == 1)
        #expect(item.children[0].name == "childMethod")
        #expect(item.children[0].id == "ParentClass/childMethod")
    }

    @Test
    func lineAndColumnProperties() {
        let lspSymbol = DocumentSymbol(
            name: "Test",
            detail: nil,
            kind: .function,
            deprecated: nil,
            range: LSPRange(start: Position(line: 5, character: 10), end: Position(line: 10, character: 0)),
            selectionRange: LSPRange(start: Position(line: 5, character: 10), end: Position(line: 5, character: 20)),
            children: nil
        )

        let item = EditorDocumentSymbolItem(symbol: lspSymbol)

        #expect(item.line == 6) // line + 1
        #expect(item.column == 11) // character + 1
    }

    @Test
    func iconSymbolForDifferentKinds() {
        let kinds: [(SymbolKind, String)] = [
            (.class, "square.stack"),
            (.struct, "shippingbox"),
            (.interface, "circle.square"),
            (.enum, "list.bullet"),
            (.enumMember, "list.bullet.indent"),
            (.function, "f.cursive"),
            (.method, "cube"),
            (.property, "p.circle"),
            (.field, "f.circle"),
            (.variable, "textformat.abc"),
            (.constant, "c.circle"),
            (.namespace, "square.3.layers.3d"),
            (.module, "shippingbox.circle"),
            (.constructor, "plus.square")
        ]

        for (kind, expectedIcon) in kinds {
            let lspSymbol = DocumentSymbol(
                name: "Test",
                detail: nil,
                kind: kind,
                deprecated: nil,
                range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 1, character: 0)),
                selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 5)),
                children: nil
            )

            let item = EditorDocumentSymbolItem(symbol: lspSymbol)
            #expect(item.iconSymbol == expectedIcon)
        }
    }

    @Test
    func iconSymbolDefaultForUnknownKind() {
        let lspSymbol = DocumentSymbol(
            name: "Test",
            detail: nil,
            kind: .file,
            deprecated: nil,
            range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 1, character: 0)),
            selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 5)),
            children: nil
        )

        let item = EditorDocumentSymbolItem(symbol: lspSymbol)
        #expect(item.iconSymbol == "doc.text")
    }

    @Test
    func containsLineInRange() {
        let lspSymbol = DocumentSymbol(
            name: "Test",
            detail: nil,
            kind: .function,
            deprecated: nil,
            range: LSPRange(start: Position(line: 5, character: 0), end: Position(line: 15, character: 0)),
            selectionRange: LSPRange(start: Position(line: 5, character: 0), end: Position(line: 5, character: 10)),
            children: nil
        )

        let item = EditorDocumentSymbolItem(symbol: lspSymbol)

        #expect(item.contains(line: 6) == true) // line 5-15 in range
        #expect(item.contains(line: 10) == true) // middle of range
        #expect(item.contains(line: 4) == false) // before range
        #expect(item.contains(line: 17) == false) // after range
    }

    @Test
    func activePathForLineInRange() {
        let lspSymbol = DocumentSymbol(
            name: "TestClass",
            detail: nil,
            kind: .class,
            deprecated: nil,
            range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 20, character: 0)),
            selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 10)),
            children: nil
        )

        let item = EditorDocumentSymbolItem(symbol: lspSymbol)

        let path = item.activePath(for: 10)
        #expect(path != nil)
        #expect(path?.count == 1)
        #expect(path?[0] == "TestClass")
    }

    @Test
    func activePathReturnsNilForOutOfRange() {
        let lspSymbol = DocumentSymbol(
            name: "Test",
            detail: nil,
            kind: .function,
            deprecated: nil,
            range: LSPRange(start: Position(line: 5, character: 0), end: Position(line: 10, character: 0)),
            selectionRange: LSPRange(start: Position(line: 5, character: 0), end: Position(line: 5, character: 5)),
            children: nil
        )

        let item = EditorDocumentSymbolItem(symbol: lspSymbol)

        let path = item.activePath(for: 0)
        #expect(path == nil)
    }

    @Test
    func activePathWithChildren() {
        let childSymbol = DocumentSymbol(
            name: "childMethod",
            detail: nil,
            kind: .method,
            deprecated: nil,
            range: LSPRange(start: Position(line: 5, character: 0), end: Position(line: 10, character: 0)),
            selectionRange: LSPRange(start: Position(line: 5, character: 0), end: Position(line: 5, character: 15)),
            children: nil
        )

        let parentSymbol = DocumentSymbol(
            name: "ParentClass",
            detail: nil,
            kind: .class,
            deprecated: nil,
            range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 20, character: 0)),
            selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 15)),
            children: [childSymbol]
        )

        let item = EditorDocumentSymbolItem(symbol: parentSymbol)

        let path = item.activePath(for: 7)
        #expect(path != nil)
        #expect(path?.count == 2)
        #expect(path?[0] == "ParentClass")
        #expect(path?[1] == "ParentClass/childMethod")
    }

    @Test
    func activeItemsForLineInRange() {
        let lspSymbol = DocumentSymbol(
            name: "TestClass",
            detail: nil,
            kind: .class,
            deprecated: nil,
            range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 20, character: 0)),
            selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 10)),
            children: nil
        )

        let item = EditorDocumentSymbolItem(symbol: lspSymbol)

        let items = item.activeItems(for: 10)
        #expect(items != nil)
        #expect(items?.count == 1)
        #expect(items?[0].name == "TestClass")
    }

    @Test
    func activeItemsWithNestedChildren() {
        let grandchildSymbol = DocumentSymbol(
            name: "grandchild",
            detail: nil,
            kind: .property,
            deprecated: nil,
            range: LSPRange(start: Position(line: 7, character: 0), end: Position(line: 8, character: 0)),
            selectionRange: LSPRange(start: Position(line: 7, character: 0), end: Position(line: 7, character: 10)),
            children: nil
        )

        let childSymbol = DocumentSymbol(
            name: "childMethod",
            detail: nil,
            kind: .method,
            deprecated: nil,
            range: LSPRange(start: Position(line: 5, character: 0), end: Position(line: 15, character: 0)),
            selectionRange: LSPRange(start: Position(line: 5, character: 0), end: Position(line: 5, character: 15)),
            children: [grandchildSymbol]
        )

        let parentSymbol = DocumentSymbol(
            name: "ParentClass",
            detail: nil,
            kind: .class,
            deprecated: nil,
            range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 20, character: 0)),
            selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 15)),
            children: [childSymbol]
        )

        let item = EditorDocumentSymbolItem(symbol: parentSymbol)

        let items = item.activeItems(for: 8)
        #expect(items != nil)
        #expect(items?.count == 3)
        #expect(items?[0].name == "ParentClass")
        #expect(items?[1].name == "childMethod")
        #expect(items?[2].name == "grandchild")
    }

    @Test
    func equality() {
        let lspSymbol1 = DocumentSymbol(
            name: "Test",
            detail: nil,
            kind: .function,
            deprecated: nil,
            range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 5, character: 0)),
            selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 5)),
            children: nil
        )

        let lspSymbol2 = DocumentSymbol(
            name: "Test",
            detail: nil,
            kind: .function,
            deprecated: nil,
            range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 5, character: 0)),
            selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 5)),
            children: nil
        )

        let item1 = EditorDocumentSymbolItem(symbol: lspSymbol1)
        let item2 = EditorDocumentSymbolItem(symbol: lspSymbol2)

        #expect(item1 == item2)
    }

    @Test
    func inequality() {
        let lspSymbol1 = DocumentSymbol(
            name: "Test1",
            detail: nil,
            kind: .function,
            deprecated: nil,
            range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 5, character: 0)),
            selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 5)),
            children: nil
        )

        let lspSymbol2 = DocumentSymbol(
            name: "Test2",
            detail: nil,
            kind: .function,
            deprecated: nil,
            range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 5, character: 0)),
            selectionRange: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 5)),
            children: nil
        )

        let item1 = EditorDocumentSymbolItem(symbol: lspSymbol1)
        let item2 = EditorDocumentSymbolItem(symbol: lspSymbol2)

        #expect(item1 != item2)
    }
}