//
//  NetworkClientHelpers.swift
//  EVPulse
//
//  Created by Nikolas Konstantakopoulos on 11/2/22.
//

import Foundation

internal class SynchronizedDictionary<K: Hashable, V> {
    private var dictionary = [K: V]()
    private let queue = DispatchQueue(
        label: "SynchronizedDictionary",
        qos: DispatchQoS.userInitiated,
        attributes: [DispatchQueue.Attributes.concurrent],
        autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit,
        target: nil
    )

    internal subscript(key: K) -> V? {
        get {
            var value: V?

            queue.sync {
                value = self.dictionary[key]
            }

            return value
        }
        set {
            queue.sync(flags: DispatchWorkItemFlags.barrier) {
                self.dictionary[key] = newValue
            }
        }
    }
    
    func remove(key: Dictionary<K, V>.Key) {
        queue.sync(flags: DispatchWorkItemFlags.barrier) {
            _ = self.dictionary.removeValue(forKey: key)
        }
    }
    
    func remove(keys: Dictionary<K, V>.Keys) {
        queue.sync(flags: DispatchWorkItemFlags.barrier) {
            keys.forEach { self.dictionary.removeValue(forKey: $0) }
        }
    }
    
    func filter(predicate: (Dictionary<K, V>.Element) -> Bool) -> [K:V] {
        var result: [K: V]!
        queue.sync {
            result = dictionary.filter(predicate)
        }
        
        return result
    }
}

