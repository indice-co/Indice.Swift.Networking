//
//  NetworkClientHelpers.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 11/2/22.
//

import Foundation

internal class SynchronizedDictionary<K: Hashable, V> {
    private var dictionary = [K: V]()
    private let queue = DispatchQueue(label: "SynchronizedDictionary",
                                      qos: DispatchQoS.userInitiated,
                                      attributes: [.concurrent],
                                      autoreleaseFrequency: .inherit,
                                      target: nil)

    internal subscript(key: K) -> V? {
        get {
            var value: V?

            queue.sync {
                value = self.dictionary[key]
            }

            return value
        }
        set {
            queue.sync(flags: .barrier) {
                self.dictionary[key] = newValue
            }
        }
    }
    
    @discardableResult
    func remove(key: [K: V].Key) -> V? {
        var result: V?
        queue.sync(flags: .barrier) {
            result = self.dictionary.removeValue(forKey: key)
        }
        
        return result
    }
    
    func remove(keys: [K: V].Keys) {
        queue.sync(flags: .barrier) {
            keys.forEach { self.dictionary.removeValue(forKey: $0) }
        }
    }
    
    func filter(predicate: ([K: V].Element) -> Bool) -> [K: V] {
        var result: [K: V]!
        queue.sync {
            result = dictionary.filter(predicate)
        }
        
        return result
    }
}

