//
//  OSLogStream.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 18/12/25.
//



import OSLog


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
    
    private var osLogStream: LogStream?
    
    private let subsystem: String
    
    public init(subsystem: String = Bundle.main.bundleIdentifier ?? "indice.network.client") {
        self.subsystem = subsystem
        if #available(iOS 14, macOS 11, *) {
            self.osLogStream = OSLogStream(subsystem: subsystem)
        } else {
            self.osLogStream = nil
        }
    }
    
    public func log(_ message: String) {
        if #available(iOS 14, macOS 11, *), let osLogStream = self.osLogStream {
            osLogStream.log(message)
        } else {
            NSLog("%@", message)
        }
    }
    
    public func log(_ message: String, for type: LogType) {
        if #available(iOS 14, macOS 11, *), let osLogStream = self.osLogStream {
            osLogStream.log(message, for: type)
        } else {
            NSLog("%@", message)
        }
    }
    
}


public extension LogStream where Self == DefaultLogStream {
    static var `default`: DefaultLogStream { .init() }
}
