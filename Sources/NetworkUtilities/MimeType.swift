//
//  MimeType.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 30/7/24.
//


import UniformTypeIdentifiers

#if os(iOS)
import MobileCoreServices
#endif

internal extension URL {
    var mimeType: String? {
        guard self.isFileURL else {
            return nil
        }
        
        if #available(iOS 14, macOS 11.0, *),
           let mime = UTType(filenameExtension: pathExtension)?.preferredMIMEType
        {
            return mime
        }
        
        if
            let id = UTTypeCreatePreferredIdentifierForTag(
                kUTTagClassFilenameExtension,
                pathExtension as CFString, nil
            )?.takeRetainedValue(),
            
            let contentType = UTTypeCopyPreferredTagWithClass(
                id, kUTTagClassMIMEType
            )?.takeRetainedValue()
        {
            return contentType as String
        }

        return nil
    }
}
