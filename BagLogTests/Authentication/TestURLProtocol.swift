import Foundation
import Synchronization

final class TestURLProtocol: URLProtocol {
    private static let response = Mutex<(statusCode: Int, data: Data, errorCode: URLError.Code?)>(
        (200, Data(), nil)
    )
    private static let recordedRequest = Mutex<URLRequest?>(nil)

    static func configure(
        statusCode: Int = 200,
        data: Data = Data(),
        errorCode: URLError.Code? = nil
    ) {
        response.withLock {
            $0 = (statusCode, data, errorCode)
        }
        recordedRequest.withLock { $0 = nil }
    }

    static func request() -> URLRequest? {
        recordedRequest.withLock { $0 }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        var recordedRequest = request
        if recordedRequest.httpBody == nil,
           let bodyStream = recordedRequest.httpBodyStream {
            bodyStream.open()
            defer { bodyStream.close() }

            var body = Data()
            var buffer = [UInt8](repeating: 0, count: 1_024)
            while bodyStream.hasBytesAvailable {
                let count = bodyStream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                body.append(buffer, count: count)
            }
            recordedRequest.httpBody = body
        }
        Self.recordedRequest.withLock { $0 = recordedRequest }
        let stub = Self.response.withLock { $0 }

        if let errorCode = stub.errorCode {
            client?.urlProtocol(self, didFailWithError: URLError(errorCode))
            return
        }

        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: stub.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
