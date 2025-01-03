//
//  URLSessionHTTPClientTests.swift
//  HTTPClient
//
//  Created by Denys Kotenko on 3/1/25.
//

import XCTest
import HTTPClient

class URLSessionHTTPClient {
	private let session: URLSession
	
	private struct UnexpectedValuesError: Error {}
	
	init(session: URLSession = .shared) {
		self.session = session
	}
	
	func perform(_ request: URLRequest, completion: @escaping (HTTPClient.Result) -> Void) {
		session.dataTask(with: request) { data, response, error in
			if let error {
				completion(.failure(error))
			}
			else {
				completion(.failure(UnexpectedValuesError()))
			}
		}.resume()
	}
}

final class URLSessionHTTPClientTests: XCTestCase {
	override func setUp() {
		super.setUp()
		
		URLProtocolStub.startInterceptingRequests()
	}
	
	override func tearDown() {
		URLProtocolStub.stopInterceptingRequests()
		
		super.tearDown()
	}
	
	func test_performRequest_preformsGETRequestWithURL() {
		let url = URL(string: "http://a-url.com")!
		let request = URLRequest(url: url)
		let exp = expectation(description: "Wait for request")
		
		URLProtocolStub.observeRequests { request in
			XCTAssertEqual(request.url, url)
			XCTAssertEqual(request.httpMethod, "GET")
			exp.fulfill()
		}
		
		makeSUT().perform(request) { _ in }
		
		wait(for: [exp], timeout: 1.0)
	}
	
	func test_performRequest_failsOnRequestError() {
		let error = anyError()
		let receivedError = resultErrorFor(data: nil, response: nil, error: error) as? NSError

		XCTAssertEqual(receivedError?.domain, error.domain)
		XCTAssertEqual(receivedError?.code, error.code)
	}
	
	func test_performRequest_failsOnAllInvalidRepresentationCases() {
		XCTAssertNotNil(resultErrorFor(data: nil, response: nil, error: nil))
		XCTAssertNotNil(resultErrorFor(data: nil, response: nonHTTPURLResponse(), error: nil))
		XCTAssertNotNil(resultErrorFor(data: anyData(), response: nil, error: nil))
		XCTAssertNotNil(resultErrorFor(data: anyData(), response: nil, error: anyError()))
		XCTAssertNotNil(resultErrorFor(data: nil, response: nonHTTPURLResponse(), error: anyError()))
		XCTAssertNotNil(resultErrorFor(data: nil, response: anyHTTPURLResponse(), error: anyError()))
		XCTAssertNotNil(resultErrorFor(data: anyData(), response: nonHTTPURLResponse(), error: anyError()))
		XCTAssertNotNil(resultErrorFor(data: anyData(), response: anyHTTPURLResponse(), error: anyError()))
		XCTAssertNotNil(resultErrorFor(data: anyData(), response: nonHTTPURLResponse(), error: nil))
	}
	
	// MARK: - Helpers
	
	private func makeSUT() -> URLSessionHTTPClient {
		URLSessionHTTPClient()
	}
	
	private func resultErrorFor(data: Data?, response: URLResponse?, error: Error?, file: StaticString = #file, line: UInt = #line) -> Error? {
		let result = resultFor(data: data, response: response, error: error)
		switch result {
		case let .failure(error):
			return error
			
		default:
			XCTFail("Expected failure, got \(result) instead", file: file, line: line)
			return nil
		}
	}
	
	private func resultFor(data: Data?, response: URLResponse?, error: Error?) -> HTTPClient.Result {
		URLProtocolStub.stub(data: data, response: response, error: error)
		
		let exp = expectation(description: "Wait request completion")
		
		var receivedResult: HTTPClient.Result!
		makeSUT().perform(anyRequest()) { result in
			receivedResult = result
			exp.fulfill()
		}
		
		wait(for: [exp], timeout: 1.0)
		return receivedResult
	}
	
	private func anyURL() -> URL {
		URL(string: "http://any-url.com")!
	}
	
	private func anyRequest() -> URLRequest {
		URLRequest(url: anyURL())
	}
	
	private func anyData() -> Data {
		Data("any data".utf8)
	}
	
	private func anyError() -> NSError {
		NSError(domain: "any error", code: 1)
	}
	
	private func anyHTTPURLResponse() -> HTTPURLResponse {
		HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
	}
	
	private func nonHTTPURLResponse() -> URLResponse {
		URLResponse(url: anyURL(), mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
	}
	
	// MARK: - URLProtocolStub
	
	class URLProtocolStub: URLProtocol {
		private struct Stub {
			let data: Data?
			let response: URLResponse?
			let error: Error?
		}
		
		private static var stub: Stub?
		
		static func stub(data: Data?, response: URLResponse?, error: Error?) {
			stub = .init(data: data, response: response, error: error)
		}
		
		private static var requestObserver: ((URLRequest) -> Void)?
		
		static func observeRequests(_ observer: @escaping ((URLRequest) -> Void)) {
			requestObserver = observer
		}
		
		static func startInterceptingRequests() {
			URLProtocol.registerClass(URLProtocolStub.self)
		}
		
		static func stopInterceptingRequests() {
			URLProtocol.unregisterClass(URLProtocolStub.self)
			stub = nil
		}
		
		override class func canInit(with request: URLRequest) -> Bool {
			true
		}
		
		override class func canonicalRequest(for request: URLRequest) -> URLRequest {
			request
		}
		
		override func startLoading() {
			if let requestObserver = URLProtocolStub.requestObserver {
				client?.urlProtocolDidFinishLoading(self)
				return requestObserver(request)
			}
			
			if let error = URLProtocolStub.stub?.error {
				client?.urlProtocol(self, didFailWithError: error)
			}
			
			client?.urlProtocolDidFinishLoading(self)
		}
		
		override func stopLoading() {}
	}
}
