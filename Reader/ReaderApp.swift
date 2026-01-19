//
//  ReaderApp.swift
//  Reader
//
//  Created by Hannes Nagel on 1/17/26.
//

import SwiftUI
import UniformTypeIdentifiers

@main
struct ReaderApp: App {
    var body: some Scene {
        DocumentGroup(viewing: ReaderDocument.self) { file in
            ContentView(document: file.document)
        }
    }
}
