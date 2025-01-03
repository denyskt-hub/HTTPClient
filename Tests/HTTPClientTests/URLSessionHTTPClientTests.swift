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
		let sut = makeSUT()
		let anyUrl = URL(string: "http://any-url.com")!
		let anyRequest = URLRequest(url: anyUrl)
		
		let exp = expectation(description: "Wait request completion")
		
		let error = NSError(domain: "any error", code: 1)
		URLProtocolStub.stub(data: nil, response: nil, error: error)
		
		sut.perform(anyRequest) { result in
			switch result {
			case let .failure(receivedError as NSError):
				XCTAssertEqual(receivedError.domain, error.domain)
				
			default:
				XCTFail("Expected failure with \(error), got \(result)")
			}
			exp.fulfill()
		}
		
		wait(for: [exp], timeout: 1.0)
	}
	
	func test_performRequest_failsOnAllNilValues() {
		let sut = makeSUT()
		let anyUrl = URL(string: "http://any-url.com")!
		let anyRequest = URLRequest(url: anyUrl)
		
		let exp = expectation(description: "Wait request completion")
		
		URLProtocolStub.stub(data: nil, response: nil, error: nil)
		
		sut.perform(anyRequest) { result in
			switch result {
			case .failure:
				break
				
			default:
				XCTFail("Expected failure, got \(result) instead")
			}
			exp.fulfill()
		}
		
		wait(for: [exp], timeout: 1.0)
	}
	
	// MARK: - Helpers
	
	private func makeSUT() -> URLSessionHTTPClient {
		URLSessionHTTPClient()
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
