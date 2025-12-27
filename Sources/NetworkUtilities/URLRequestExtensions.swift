//
//  File.swift
//
//
//  Created by Nikolas Konstantakopoulos on 30/7/24.
//



// NetworkUtilities — URLRequest convenience starters
// Small convenience extensions that expose `URLRequest.get/put/post/...`
// builder entry points to start fluent request construction.


import Foundation

public extension URLRequest {
    
    static func get   (url: URL) -> URLRequest.QueryBuilder { builder().get   (url: url) }
    static func put   (url: URL) -> URLRequest.BodyBuilder  { builder().put   (url: url) }
    static func post  (url: URL) -> URLRequest.BodyBuilder  { builder().post  (url: url) }
    static func patch (url: URL) -> URLRequest.BodyBuilder  { builder().patch (url: url) }
    static func delete(url: URL) -> URLRequest.QueryBuilder { builder().delete(url: url) }
}

