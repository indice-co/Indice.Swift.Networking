//
//  MimeType.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 30/7/24.
//


import UniformTypeIdentifiers
import MobileCoreServices

internal extension URL {
    var mimeType: String? {
        guard self.isFileURL else {
            return nil
        }
        
        if #available(iOS 14, *),
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
