//
//  NetworkClientHelpers.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 11/2/22.
//

import Foundation



internal actor AtomicStorage<K: Hashable & Sendable, V: Sendable> {
    private var dictionary = [K: V]()
    
    func get(_ key: K) -> V? {
        self.dictionary[key]
    }
    
    func set(_ key: K, to value: V?) {
        self.dictionary[key] = value
    }
    
    @discardableResult
    func remove(key: K) -> V? {
        self.dictionary.removeValue(forKey: key)
    }
    
    func remove<S: Sequence>(keys: S) where S.Element == K {
        keys.forEach { key in
            self
                .dictionary
                .removeValue(forKey: key)
        }
    }
    
    func filter(predicate: @Sendable ([K: V].Element) -> Bool) -> [K: V] {
        dictionary.filter(predicate)
    }    
}


extension AtomicStorage where V == NetworkClient.ResultTask {
    func getOrInsert(_ key: K, create: @Sendable () -> V) -> V {
        if let existing = dictionary[key] {
            return existing
        }
        
        let new = create()
        dictionary[key] = new
        return new
    }
    
    func removeCancelled() {
        let cancelled = dictionary.compactMap {
            $1.isCancelled ? $0 : nil
        }
        
        remove(keys: cancelled)
    }
}
