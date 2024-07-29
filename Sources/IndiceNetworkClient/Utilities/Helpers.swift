//
//  Helpers.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 25/1/23.
//

import Foundation

func printIfDebug(data: Data) {
#if DEBUG
    if let stringResponse: String = String(data: data, encoding: .utf8) {
        print(stringResponse)
    } else {
        print("Cannot parse data response as String")
    }
#endif
}



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
