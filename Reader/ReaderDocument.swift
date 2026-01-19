//
//  ReaderDocument.swift
//  Reader
//
//  Created by Hannes Nagel on 1/17/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ReaderDocument: FileDocument {
    var rawData: Data?
    var fileType: UTType?
    
    // Legacy support or cache? For now just transient.
    var pages: [String] = []
    
    var textContent: String {
        pages.joined(separator: "\n")
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.rawData = data
        self.fileType = configuration.contentType
        // We delay extraction to the View to allow showing a spinner
    }
    
    // Create new empty document
    init() {
        self.pages = ["Welcome to Reader. Open a PDF or EPUB file to start reading."]
    }

    static var readableContentTypes: [UTType] {
        [.pdf, UTType("org.idpf.epub-container") ?? .epub, .plainText]
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.featureUnsupported)
    }
}
