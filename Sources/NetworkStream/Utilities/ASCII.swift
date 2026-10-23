//
//  ASCII.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 28/9/26.
//


/// Typed options to avoid magic numbers and recurring checks.
internal enum ASCIICharacter {
    static let carriageReturn = UInt8(ascii: "\r")
    static let lineFeed = UInt8(ascii: "\n")
    static let nullCharacter = "\0"
}
