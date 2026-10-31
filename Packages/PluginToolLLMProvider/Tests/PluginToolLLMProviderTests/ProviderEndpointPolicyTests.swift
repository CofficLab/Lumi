import Foundation
import Testing
@testable import PluginToolLLMProvider

/// 供应商端点地址的安全策略。
///
/// 这是「LLM 决定 baseURL」这条链路上唯一的闸门：策略放宽了，
/// LLM 就能把用户的请求导向任意地址。
struct ProviderEndpointPolicyTests {

    @Test("公网地址必须使用 https")
    func rejectsPlaintextRemoteEndpoint() {
        #expect(throws: ProviderEndpointPolicyError.insecureRemoteEndpoint("api.example.com")) {
            try ProviderEndpointPolicy.validate(baseURL: "http://api.example.com/v1")
        }
    }

    @Test("公网 https 地址通过校验")
    func acceptsHTTPSRemoteEndpoint() throws {
        let url = try ProviderEndpointPolicy.validate(baseURL: "https://api.example.com/v1")
        #expect(url.host == "api.example.com")
    }

    @Test("回环地址允许 http（本机网关的常见形态）")
    func acceptsPlaintextLoopbackEndpoint() throws {
        #expect(throws: Never.self) {
            try ProviderEndpointPolicy.validate(baseURL: "http://localhost:1234/v1")
        }
        #expect(throws: Never.self) {
            try ProviderEndpointPolicy.validate(baseURL: "http://127.0.0.1:1234/v1")
        }
    }

    @Test("私网网段一律拒绝")
    func rejectsPrivateNetworkEndpoints() {
        let privateHosts = [
            "10.1.2.3",
            "172.16.0.1",
            "172.31.255.254",
            "192.168.1.10",
            "169.254.10.10",
            "100.64.0.1",
            "gateway.local",
        ]
        for host in privateHosts {
            #expect(throws: ProviderEndpointPolicyError.privateNetworkAddress(host)) {
                try ProviderEndpointPolicy.validate(baseURL: "https://\(host)/v1")
            }
        }
    }

    @Test("IPv6 唯一本地地址与链路本地地址拒绝")
    func rejectsIPv6PrivateEndpoints() {
        #expect(throws: ProviderEndpointPolicyError.privateNetworkAddress("fd00::1")) {
            try ProviderEndpointPolicy.validate(baseURL: "https://[fd00::1]/v1")
        }
        #expect(throws: ProviderEndpointPolicyError.privateNetworkAddress("fe80::1")) {
            try ProviderEndpointPolicy.validate(baseURL: "https://[fe80::1]/v1")
        }
    }

    @Test("172.15 与 172.32 不属于私网段")
    func allowsPublicAddressesAdjacentToPrivateRanges() throws {
        #expect(throws: Never.self) {
            try ProviderEndpointPolicy.validate(baseURL: "https://172.15.0.1/v1")
        }
        #expect(throws: Never.self) {
            try ProviderEndpointPolicy.validate(baseURL: "https://172.32.0.1/v1")
        }
    }

    @Test("非法地址与非 http 协议被拒绝")
    func rejectsMalformedAndUnsupportedSchemes() {
        #expect(throws: ProviderEndpointPolicyError.invalidURL) {
            try ProviderEndpointPolicy.validate(baseURL: "not-a-url")
        }
        #expect(throws: ProviderEndpointPolicyError.invalidURL) {
            try ProviderEndpointPolicy.validate(baseURL: "")
        }
        #expect(throws: ProviderEndpointPolicyError.unsupportedScheme("ftp")) {
            try ProviderEndpointPolicy.validate(baseURL: "ftp://files.example.com/v1")
        }
    }

    @Test("回环判定覆盖 localhost 与 127.0.0.0/8")
    func detectsLoopbackHosts() {
        #expect(ProviderEndpointPolicy.isLoopback(host: "localhost"))
        #expect(ProviderEndpointPolicy.isLoopback(host: "api.localhost"))
        #expect(ProviderEndpointPolicy.isLoopback(host: "127.0.0.1"))
        #expect(ProviderEndpointPolicy.isLoopback(host: "127.5.5.5"))
        #expect(!ProviderEndpointPolicy.isLoopback(host: "10.0.0.1"))
        #expect(!ProviderEndpointPolicy.isLoopback(host: "api.example.com"))
    }
}
