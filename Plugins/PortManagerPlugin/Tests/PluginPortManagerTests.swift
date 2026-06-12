import Testing
@testable import PortManagerPlugin

@Test func parsesLsofListeningPorts() {
    let output = """
    COMMAND   PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
    node    12345 user   21u  IPv4 0x123456789abcdef0      0t0  TCP *:3000 (LISTEN)
    nginx   23456 root    6u  IPv6 0xabcdef0123456789      0t0  TCP [::1]:8080 (LISTEN)
    vite    34567 user   22u  IPv4 0xabcdef0123456789      0t0  TCP localhost:5173 (LISTEN)
    """

    let ports = PortScanner.shared.parseLsofOutput(output)

    #expect(ports.count == 3)
    #expect(ports[0].command == "node")
    #expect(ports[0].pid == "12345")
    #expect(ports[0].port == "3000")
    #expect(ports[1].command == "nginx")
    #expect(ports[1].address == "[::1]:8080")
    #expect(ports[2].command == "vite")
    #expect(ports[2].port == "5173")
    #expect(ports[2].address == "localhost:5173")
}

@Test func ignoresMalformedLsofRows() {
    let output = """
    COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
    broken row without port
    """

    let ports = PortScanner.shared.parseLsofOutput(output)

    #expect(ports.isEmpty)
}

@Test func ignoresLsofRowsWithInvalidPorts() {
    let output = """
    COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
    app 123 user 21u IPv4 0x123 0t0 TCP localhost:notaport (LISTEN)
    """

    let ports = PortScanner.shared.parseLsofOutput(output)

    #expect(ports.isEmpty)
}
