import Foundation
import Testing
@testable import PluginHostsManager

@Suite("Hosts parser")
struct HostsParserTests {
    @Test("parses active IPv4 and IPv6 entries with inline comments")
    func parsesActiveEntries() throws {
        let entries = HostsParser.parse(content: "127.0.0.1 localhost local.test # loopback\n2001:db8::1 router.test")

        let ipv4 = try #require(entries.first)
        let ipv6 = try #require(entries.last)
        #expect(ipv4.type == .entry(ip: "127.0.0.1", domains: ["localhost", "local.test"], isEnabled: true, comment: "loopback"))
        #expect(ipv6.type == .entry(ip: "2001:db8::1", domains: ["router.test"], isEnabled: true, comment: nil))
        #expect(ipv4.ip == "127.0.0.1")
        #expect(ipv4.domains == ["localhost", "local.test"])
        #expect(ipv4.isEnabled)
    }

    @Test("distinguishes disabled entries, ordinary comments, and group headers")
    func parsesCommentsAndGroups() {
        let entries = HostsParser.parse(content: "# GROUP: Development\n# 0.0.0.0 blocked.test # disabled\n# Managed by local tooling")

        #expect(entries.map(\.type) == [
            .groupHeader("Development"),
            .entry(ip: "0.0.0.0", domains: ["blocked.test"], isEnabled: false, comment: "disabled"),
            .comment("# Managed by local tooling"),
        ])
        #expect(entries.first?.groupName == "Development")
        #expect(entries[1].isEnabled == false)
    }

    @Test("preserves intentional blank lines and omits only the terminal newline sentinel")
    func preservesBlankLines() {
        let entries = HostsParser.parse(content: "127.0.0.1 one.test\n\n127.0.0.2 two.test\n")

        #expect(entries.map(\.type) == [
            .entry(ip: "127.0.0.1", domains: ["one.test"], isEnabled: true, comment: nil),
            .empty,
            .entry(ip: "127.0.0.2", domains: ["two.test"], isEnabled: true, comment: nil),
        ])
    }

    @Test("validates IPv4, IPv6, and domain labels")
    func validatesAddressesAndDomains() {
        #expect(HostsParser.isValidIP("127.0.0.1"))
        #expect(HostsParser.isValidIP("2001:db8::1"))
        #expect(HostsParser.isValidIP(" 127.0.0.1") == false)
        #expect(HostsParser.isValidIP("256.0.0.1") == false)
        #expect(HostsParser.isValidIP("example.com") == false)

        #expect(HostsParser.isValidDomain("localhost"))
        #expect(HostsParser.isValidDomain("api.example-2.com"))
        #expect(HostsParser.isValidDomain("-invalid.example") == false)
        #expect(HostsParser.isValidDomain("invalid..example") == false)
        #expect(HostsParser.isValidDomain("contains/path") == false)
        #expect(HostsParser.isValidDomain(String(repeating: "a", count: 64) + ".example") == false)
    }

    @Test("normalizes a whitespace-separated domain list")
    func normalizesDomainList() {
        #expect(HostsParser.normalizedDomains(from: "one.test\t two.test\nthree.test") == ["one.test", "two.test", "three.test"])
    }

    @Test("serializes entries to a representation that parses back without data loss")
    func serializationRoundTrips() {
        let entries = [
            HostEntry(type: .comment("# Managed")),
            HostEntry(type: .groupHeader("Development")),
            HostEntry(type: .entry(ip: "127.0.0.1", domains: ["app.test", "api.test"], isEnabled: true, comment: "local")),
            HostEntry(type: .entry(ip: "0.0.0.0", domains: ["blocked.test"], isEnabled: false, comment: nil)),
            HostEntry(type: .empty),
        ]

        let serialized = HostsParser.serialize(entries: entries)
        let reparsed = HostsParser.parse(content: serialized)

        #expect(reparsed.map(\.type) == entries.map(\.type))
    }
}
