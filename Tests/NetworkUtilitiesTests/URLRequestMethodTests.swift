import Testing
import Foundation
@testable import NetworkUtilities

@Suite("URLRequestMethodTests")
final class URLRequestMethodTests {
        
    private let testURL = URL(string: "https://www.indice.gr")!
    
    
    @Test
    func `http verb matching`() throws {
        let verbs: [String: URLRequest.HTTPMethod] = ["GET"    : .get,
                                                      "PUT"    : .put,
                                                      "POST"   : .post,
                                                      "PATCH"  : .patch,
                                                      "DELETE" : .delete]
    
        // Check HTTPMethod creation
        
        for (written, typed) in verbs {
            let created = URLRequest.HTTPMethod(rawValue: written)
            
            #expect(created != nil)
            #expect(typed == created)
        }
        
        
        // Check Request verb from assignment
        
        for (written, typed) in verbs {
            var request = URLRequest(url: testURL)
            request.method = typed
            
            #expect(request.httpMethod == written)
        }
        
        
        // Check Request verb from default assignment
        
        for (written, typed) in verbs {
            var request = URLRequest(url: testURL)
            request.httpMethod = written
            
            #expect(request.method == typed)
        }
    }
    
    
    @Test
    func `method verb GET`() throws {
        let built = URLRequest
            .get(url: testURL)
            .build()
        
        let test  = {
            var request = URLRequest(url: testURL)
            request.method = .get
            
            return request
        }()
        
        #expect(built == test)
    }


    @Test
    func `method verb PUT`() throws {
        let built = URLRequest
            .put(url: testURL)
            .noBody()
            .build()
        
        let test  = {
            var request = URLRequest(url: testURL)
            request.method = .put
            
            return request
        }()
        
        #expect(built == test)
    }

    
    @Test
    func `method verb POST`() throws {
        let built = URLRequest
            .post(url: testURL)
            .noBody()
            .build()
        
        let test  = {
            var request = URLRequest(url: testURL)
            request.method = .post
            
            return request
        }()
        
        #expect(built == test)
    }
    
    
    @Test
    func `method verb PATCH`() throws {
        let built = URLRequest
            .patch(url: testURL)
            .noBody()
            .build()
        
        let test  = {
            var request = URLRequest(url: testURL)
            request.method = .patch
            
            return request
        }()
        
        #expect(built == test)
    }
    
    
    @Test
    func `method verb DELETE`() throws {
        let built = URLRequest
            .delete(url: testURL)
            .build()
        
        let test  = {
            var request = URLRequest(url: testURL)
            request.method = .delete
            
            return request
        }()
        
        #expect(built == test)
    }
    
}
