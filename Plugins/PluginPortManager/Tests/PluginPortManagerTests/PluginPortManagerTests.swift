import Testing
@testable import PluginPortManager

@Test func parsesLsofListeningPorts() {
    let output = """
    COMMAND   PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
    node    12345 user   21u  IPv4 0x123456789abcdef0      0t0  TCP *:3000 (LISTEN)
    nginx   23456 root    6u  IPv6 0xabcdef0123456789      0t0  TCP [::1]:8080 (LISTEN)
    """

    let ports = PortScanner.shared.parseLsofOutput(output)

    #expect(ports.count == 2)
    #expect(ports[0].command == "node")
    #expect(ports[0].pid == "12345")
    #expect(ports[0].port == "3000")
    #expect(ports[1].command == "nginx")
    #expect(ports[1].address == "[::1]:8080")
}

@Test func ignoresMalformedLsofRows() {
    let output = """
    COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
    broken row without port
    """

    let ports = PortScanner.shared.parseLsofOutput(output)

    #expect(ports.isEmpty)
}
