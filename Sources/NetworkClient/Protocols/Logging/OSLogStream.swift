//
//  OSLogStream.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 18/12/25.
//



import OSLog


fileprivate struct FallbackLogStream: LogStream {
    let subsystem: String
    
    public func log(_ message: String) {
        NSLog("%@: %@", subsystem, message)
    }
    
    public func log(_ message: String, for type: LogType) {
        NSLog("%@ | %@: %@", subsystem, "\(type)", message)
    }
}

@available(iOS 14, macOS 11, *)
public struct OSLogStream: LogStream {
    
    private let logger: Logger
    
    public init(subsystem: String = Bundle.main.bundleIdentifier ?? "indice.network.client") {
        self.logger = Logger(subsystem: subsystem, category: "NetworkClient")
    }

    public func log(_ message: String) {
        log(message, for: .info)
    }
    public func log(_ message: String, for type: LogType) {
        logger.log(level: type.osLogType, "\(message)")
    }
}


@available(iOS 14, macOS 11, *)
internal extension LogType {
    var osLogType: OSLogType {
        switch self {
        case .info      : .default
        case .warning   : .error
        case .critical  : .fault
        }
    }
}


public struct DefaultLogStream: LogStream {
    
    private let osLogStream: LogStream
    public init(subsystem: String = Bundle.main.bundleIdentifier ?? "indice.network.client") {
        if #available(iOS 14, macOS 11, *) {
            self.osLogStream = OSLogStream(subsystem: subsystem)
        } else {
            self.osLogStream = FallbackLogStream(subsystem: subsystem)
        }
    }
    
    public func log(_ message: String) {
        osLogStream.log(message)
    }
    
    public func log(_ message: String, for type: LogType) {
        osLogStream.log(message, for: type)
    }
    
}


public extension LogStream where Self == DefaultLogStream {
    static var `default`: DefaultLogStream { .init() }
}
