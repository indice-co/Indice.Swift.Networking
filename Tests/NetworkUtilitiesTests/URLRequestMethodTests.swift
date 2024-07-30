import XCTest
@testable import NetworkUtilities

final class URLRequestMethodTests: XCTestCase {
        
    private let testURL = URL(string: "https://www.indice.gr")!
    
    func testURLRequestHTTPVerb() throws {
        let verbs: [String: URLRequest.HTTPMethod] = ["GET"    : .get,
                                                      "PUT"    : .put,
                                                      "POST"   : .post,
                                                      "PATCH"  : .patch,
                                                      "DELETE" : .delete]
    
        // Check HTTPMethod creation
        
        for (written, typed) in verbs {
            let created = URLRequest.HTTPMethod(rawValue: written)
            
            XCTAssertNotNil(created)
            XCTAssertEqual(typed, created)
        }
        
        
        // Check Request verb from assignment
        
        for (written, typed) in verbs {
            var request = URLRequest(url: testURL)
            request.method = typed
            
            XCTAssertEqual(request.httpMethod, written)
        }
        
        
        // Check Request verb from default assignment
        
        for (written, typed) in verbs {
            var request = URLRequest(url: testURL)
            request.httpMethod = written
            
            XCTAssertEqual(request.method, typed)
        }
    }
    
    
    func testURLRequestBuilder_GET() throws {
        let built = URLRequest
            .get(url: testURL)
            .build()
        
        let test  = {
            var request = URLRequest(url: testURL)
            request.method = .get
            
            return request
        }()
        
        XCTAssertEqual(built, test)
    }


    func testURLRequestBuilder_PUT() throws {
        let built = URLRequest
            .put(url: testURL)
            .noBody()
            .build()
        
        let test  = {
            var request = URLRequest(url: testURL)
            request.method = .put
            
            return request
        }()
        
        XCTAssertEqual(built, test)
    }

    func testURLRequestBuilder_POST() throws {
        let built = URLRequest
            .post(url: testURL)
            .noBody()
            .build()
        
        let test  = {
            var request = URLRequest(url: testURL)
            request.method = .post
            
            return request
        }()
        
        XCTAssertEqual(built, test)
    }
    
    
    func testURLRequestBuilder_PATCH() throws {
        let built = URLRequest
            .patch(url: testURL)
            .noBody()
            .build()
        
        let test  = {
            var request = URLRequest(url: testURL)
            request.method = .patch
            
            return request
        }()
        
        XCTAssertEqual(built, test)
    }
    
    
    func testURLRequestBuilder_DELETE() throws {
        let built = URLRequest
            .delete(url: testURL)
            .build()
        
        let test  = {
            var request = URLRequest(url: testURL)
            request.method = .delete
            
            return request
        }()
        
        XCTAssertEqual(built, test)
    }
    
}
