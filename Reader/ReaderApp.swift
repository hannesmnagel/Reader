//
//  ReaderApp.swift
//  Reader
//
//  Created by Hannes Nagel on 1/17/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@main
struct ReaderApp: App {
    var body: some Scene {
        DocumentGroup(editing: .itemDocument, migrationPlan: ReaderMigrationPlan.self) {
            ContentView()
        }
    }
}

extension UTType {
    static var itemDocument: UTType {
        UTType(importedAs: "com.example.item-document")
    }
}

struct ReaderMigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] = [
        ReaderVersionedSchema.self,
    ]

    static var stages: [MigrationStage] = [
        // Stages of migration between VersionedSchema, if required.
    ]
}

struct ReaderVersionedSchema: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] = [
        Item.self,
    ]
}
