import Testing
@testable import PluginHostsManager

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
