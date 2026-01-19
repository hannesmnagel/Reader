//
//  ContentView.swift
//  Reader
//
//  Created by Hannes Nagel on 1/17/26.
//

import SwiftUI

struct ContentView: View {
    let document: ReaderDocument
    @State private var readingMode: ReadingMode = .wordFlash
    
    // View State for Async Loading
    @State private var pages: [String] = []
    @State private var isLoading = true
    
    // Full Screen Mode
    @State private var isFullScreen = false
    
    enum ReadingMode: String, CaseIterable, Identifiable {
        case wordFlash = "Word Flash"
        case boldPrefix = "Bold Prefix"
        var id: String { self.rawValue }
    }
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Analyzing Document...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    if !isFullScreen {
                        Picker("Reading Mode", selection: $readingMode) {
                            ForEach(ReadingMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    if !isFullScreen {
                        Spacer()
                    }
                    
                    switch readingMode {
                    case .wordFlash:
                        WordFlashView(pages: pages)
                    case .boldPrefix:
                        BoldPrefixView(text: pages.joined(separator: "\n"), onToggleFullScreen: {
                            withAnimation {
                                isFullScreen.toggle()
                            }
                        })
                    }
                    
                    if !isFullScreen {
                        Spacer()
                    }
                }
                .padding(isFullScreen ? 0 : 16)
            }
        }
        .task {
            await loadDocument()
        }
        #if os(iOS)
        .toolbar(isFullScreen ? .hidden : .visible, for: .navigationBar)
        .statusBar(hidden: isFullScreen)
        #endif
    }
    
    private func loadDocument() async {
        // If document already has pages (e.g. from init blank), use them
        if !document.pages.isEmpty {
            self.pages = document.pages
            self.isLoading = false
            return
        }
        
        // Otherwise extract from raw data
        guard let data = document.rawData, let type = document.fileType else { return }
        
        self.isLoading = true
        
        // Run extraction in background
        let extractedPages = await Task.detached(priority: .userInitiated) {
            return ContentExtractor.extractText(from: data, type: type)
        }.value
        
        await MainActor.run {
            self.pages = extractedPages
            self.isLoading = false
        }
    }
}

#Preview {
    ContentView(document: ReaderDocument())
}
