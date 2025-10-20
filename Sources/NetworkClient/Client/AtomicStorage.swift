//
//  NetworkClientHelpers.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 11/2/22.
//

import Foundation



internal actor AtomicStorage<K: Hashable, V> {
    private var dictionary = [K: V]()
    
    func get(_ key: K) -> V? {
        self.dictionary[key]
    }
    
    func set(_ key: K, to value: V?) {
        self.dictionary[key] = value
    }
    
    @discardableResult
    func remove(key: [K: V].Key) -> V? {
        self.dictionary.removeValue(forKey: key)
    }
    
    func remove(keys: [K: V].Keys) {
        keys.forEach { key in
            self
                .dictionary
                .removeValue(forKey: key)
        }
    }
    
    func filter(predicate: ([K: V].Element) -> Bool) -> [K: V] {
        dictionary.filter(predicate)
    }
}

