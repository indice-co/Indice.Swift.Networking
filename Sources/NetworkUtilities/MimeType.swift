//
//  MimeType.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 30/7/24.
//
//  NetworkUtilities — MimeType
//  Helper to infer a file's MIME type from its URL. Uses modern
//  `UniformTypeIdentifiers` where available and falls back to
//  legacy system APIs on older platforms.

import UniformTypeIdentifiers

#if os(iOS)
import MobileCoreServices
#endif

internal extension URL {
    
    /// Returns the MimeType value if the URL is a valid fileURL
    var mimeType: String? {
        guard self.isFileURL else {
            return nil
        }
        
        guard #unavailable(iOS 14, macOS 11) else {
            return UTType(
                filenameExtension: pathExtension)?
                .preferredMIMEType
        }
        
        let id = UTTypeCreatePreferredIdentifierForTag(
            kUTTagClassFilenameExtension,
            pathExtension as CFString,
            nil
        )?.takeRetainedValue()
        
        let contentType = id.map { id in
            UTTypeCopyPreferredTagWithClass(id, kUTTagClassMIMEType)?
                .takeRetainedValue()
        }
        
        return contentType as? String
    }
}
