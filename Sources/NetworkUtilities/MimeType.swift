//
//  MimeType.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 30/7/24.
//


// NetworkUtilities — MimeType
// Helper to infer a file's MIME type from its URL. Uses modern
// `UniformTypeIdentifiers` where available and falls back to
// legacy system APIs on older platforms.

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
