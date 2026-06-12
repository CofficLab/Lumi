import Testing
@testable import RequestLogPlugin
import Foundation

@Suite("RequestLogItemDTO")
struct RequestLogItemDTOTests {

    @Test("DTO 从 RequestLogItem 正确映射所有字段")
    func testMappingFromItem() {
        let requestId = UUID()
        let timestamp = Date()

        let item = RequestLogItem(
            requestId: requestId,
            timestamp: timestamp,
            method: "POST",
            requestURL: "https://api.example.com/v1/chat",
            requestHeadersJSON: "{\"content-type\":\"application/json\"}",
            requestBodySize: 1024,
            requestBodyPreview: "Hello",
            responseStatusCode: 200,
            responseHeadersJSON: nil,
            responseBodySize: 2048,
            responseBodyPreview: "World",
            isSuccess: true,
            errorMessage: nil,
            duration: 1.5
        )

        let dto = RequestLogItemDTO(from: item)

        #expect(dto.requestId == requestId)
        #expect(dto.timestamp == timestamp)
        #expect(dto.method == "POST")
        #expect(dto.requestURL == "https://api.example.com/v1/chat")
        #expect(dto.requestBodySize == 1024)
        #expect(dto.requestBodyPreview == "Hello")
        #expect(dto.responseStatusCode == 200)
        #expect(dto.responseBodySize == 2048)
        #expect(dto.responseBodyPreview == "World")
        #expect(dto.isSuccess == true)
        #expect(dto.errorMessage == nil)
        #expect(dto.duration == 1.5)
    }

    @Test("DTO 正确映射失败请求")
    func testMappingFailedRequest() {
        let requestId = UUID()
        let item = RequestLogItem(
            requestId: requestId,
            timestamp: Date(),
            method: "GET",
            requestURL: "https://api.example.com/error",
            requestHeadersJSON: nil,
            requestBodySize: 0,
            requestBodyPreview: nil,
            responseStatusCode: nil,
            responseHeadersJSON: nil,
            responseBodySize: nil,
            responseBodyPreview: nil,
            isSuccess: false,
            errorMessage: "Connection timeout",
            duration: 30.0
        )

        let dto = RequestLogItemDTO(from: item)

        #expect(dto.isSuccess == false)
        #expect(dto.responseStatusCode == nil)
        #expect(dto.errorMessage == "Connection timeout")
        #expect(dto.duration == 30.0)
    }

    @Test("DTO 是 Sendable")
    func testSendable() {
        let requestId = UUID()
        let item = RequestLogItem(
            requestId: requestId,
            timestamp: Date(),
            method: "POST",
            requestURL: "https://api.example.com",
            requestHeadersJSON: nil,
            requestBodySize: 100,
            requestBodyPreview: nil,
            responseStatusCode: 200,
            responseHeadersJSON: nil,
            responseBodySize: 200,
            responseBodyPreview: "OK",
            isSuccess: true,
            errorMessage: nil,
            duration: 0.5
        )

        let dto = RequestLogItemDTO(from: item)
        // DTO 声明为 Sendable，可在并发上下文中传递
        let _: @Sendable () -> RequestLogItemDTO = { dto }
        #expect(dto.method == "POST")
    }

    @Test("DTO 是 Identifiable")
    func testIdentifiable() {
        let requestId = UUID()
        let item = RequestLogItem(
            requestId: requestId,
            timestamp: Date(),
            method: "POST",
            requestURL: "https://api.example.com",
            requestHeadersJSON: nil,
            requestBodySize: 0,
            requestBodyPreview: nil,
            responseStatusCode: nil,
            responseHeadersJSON: nil,
            responseBodySize: nil,
            responseBodyPreview: nil,
            isSuccess: true,
            errorMessage: nil,
            duration: nil
        )
        let dto = RequestLogItemDTO(from: item)
        #expect(dto.id == item.id)
    }
}
