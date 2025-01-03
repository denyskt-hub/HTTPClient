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
	
	init(session: URLSession = .shared) {
		self.session = session
	}
	
	func perform(request: URLRequest, completion: @escaping (HTTPClient.Result) -> Void) {
		session.dataTask(with: request) { data, response, error in
			if let error {
				completion(.failure(error))
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
	
	func test_performRequest_failsOnRequestError() {
		let sut = makeSUT()
		let anyUrl = URL(string: "http://any-url.com")!
		let anyRequest = URLRequest(url: anyUrl)
		
		let exp = expectation(description: "Wait request completion")
		
		let error = NSError(domain: "any error", code: 1)
		URLProtocolStub.stub(error: error)
		
		sut.perform(request: anyRequest) { result in
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
	
	// MARK: - Helpers
	
	private func makeSUT() -> URLSessionHTTPClient {
		URLSessionHTTPClient()
	}
	
	class URLProtocolStub: URLProtocol {
		private struct Stub {
			let error: Error?
		}
		
		private static var stub: Stub?
		
		static func stub(error: Error?) {
			stub = .init(error: error)
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
			if let error = URLProtocolStub.stub?.error {
				client?.urlProtocol(self, didFailWithError: error)
			}
			
			client?.urlProtocolDidFinishLoading(self)
		}
		
		override func stopLoading() {}
	}
}
