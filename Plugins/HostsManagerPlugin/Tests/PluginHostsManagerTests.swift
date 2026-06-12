import Foundation
import Testing
@testable import HostsManagerPlugin

@Test func ipValidationRejectsOutOfRangeIPv4() {
    #expect(HostsParser.isValidIP("127.0.0.1"))
    #expect(HostsParser.isValidIP("192.168.1.10"))
    #expect(!HostsParser.isValidIP("999.999.999.999"))
    #expect(!HostsParser.isValidIP("256.0.0.1"))
    #expect(!HostsParser.isValidIP("127.0.0"))
    #expect(!HostsParser.isValidIP(" 127.0.0.1 "))
}

@Test func ipValidationAcceptsRealIPv6() {
    #expect(HostsParser.isValidIP("::1"))
    #expect(HostsParser.isValidIP("2001:db8::1"))
    #expect(!HostsParser.isValidIP("2001:db8:::1"))
}

@Test func parserSkipsInvalidHostAddresses() {
    let entries = HostsParser.parse(content: """
    127.0.0.1 localhost
    999.999.999.999 broken.example
    """)

    #expect(entries.contains { entry in
        if case .entry(let ip, let domains, true, nil) = entry.type {
            return ip == "127.0.0.1" && domains == ["localhost"]
        }
        return false
    })
    #expect(!entries.contains { entry in
        if case .entry(let ip, _, _, _) = entry.type {
            return ip == "999.999.999.999"
        }
        return false
    })
}

@Test func domainValidationRejectsHostsUnsafeAliases() {
    #expect(HostsParser.isValidDomain("localhost"))
    #expect(HostsParser.isValidDomain("dev.example.com"))
    #expect(HostsParser.isValidDomain("api-1.example"))
    #expect(!HostsParser.isValidDomain(""))
    #expect(!HostsParser.isValidDomain(" dev.example.com "))
    #expect(!HostsParser.isValidDomain(".example.com"))
    #expect(!HostsParser.isValidDomain("example..com"))
    #expect(!HostsParser.isValidDomain("-example.com"))
    #expect(!HostsParser.isValidDomain("example-.com"))
    #expect(!HostsParser.isValidDomain("bad/example.com"))
    #expect(!HostsParser.isValidDomain("bad#example.com"))
    #expect(!HostsParser.isValidDomain("例子.test"))
}

@Test func parserSkipsInvalidHostAliases() {
    let entries = HostsParser.parse(content: """
    127.0.0.1 valid.local
    127.0.0.1 invalid#alias
    127.0.0.1 bad/path
    """)

    #expect(entries.contains { entry in
        if case .entry(let ip, let domains, true, nil) = entry.type {
            return ip == "127.0.0.1" && domains == ["valid.local"]
        }
        return false
    })
    #expect(!entries.contains { entry in
        if case .entry(_, let domains, _, _) = entry.type {
            return domains.contains("invalid#alias") || domains.contains("bad/path")
        }
        return false
    })
}

@Test func parserDoesNotTreatTerminatingNewlineAsBlankEntry() {
    let entries = HostsParser.parse(content: "127.0.0.1 localhost\n")

    #expect(entries.count == 1)
    #expect(HostsParser.serialize(entries: entries) == "127.0.0.1 localhost\n")
}

@Test func parserPreservesIntentionalBlankLinesBeforeTerminatingNewline() {
    let entries = HostsParser.parse(content: "127.0.0.1 localhost\n\n")

    #expect(entries.count == 2)
    #expect(HostsParser.serialize(entries: entries) == "127.0.0.1 localhost\n\n")
}

@Test func parserPreservesSingleBlankLineWithoutTerminatingNewline() {
    let entries = HostsParser.parse(content: "   ")

    #expect(entries.count == 1)
    #expect(HostsParser.serialize(entries: entries) == "\n")
}

@Test func hostsFileReaderDetectsUTF16Input() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("lumi_hosts_utf16_\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: url) }

    let content = "127.0.0.1 localhost\n::1 localhost\n"
    try content.write(to: url, atomically: true, encoding: .utf16)

    #expect(try HostsFileService.readTextFile(at: url) == content)
}
