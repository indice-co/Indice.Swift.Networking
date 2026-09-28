//
//  StringCharacterExtensions.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 28/9/26.
//


internal extension UInt8 {
    
    /// Check if the character is in the [0-9] ascii code digits.
    var isASCIIDigit: Bool {
        (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(self)
    }
}
    

internal extension String {
    
    /// Remove the leading Byte Order Mark, if it is present.
    func clearingBOMCharacter() -> String {
        guard self.hasPrefix("\u{FEFF}") else {
            return self
        }
        
        var copy = self
        copy.removeFirst()
        
        return copy
    }
    
    /// Remove a single leading space, if it is present.
    func clearingSingleLeadingSpace() -> String {
        guard self.hasPrefix(" ") else {
            return self
        }
        
        var copy = self
        copy.removeFirst()
        
        return copy
    }

    
    
}
