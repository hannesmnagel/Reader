//
//  WordFlashView.swift
//  Reader
//
//  Created by Hannes Nagel on 1/17/26.
//

import SwiftUI

struct WordFlashView: View {
    let pages: [String]
    var chapterTitle: String = "Chapter 1"
    
    // Flattened words with mapping to page index
    struct WordItem {
        let text: String
        let pageIndex: Int
    }
    
    @State private var words: [WordItem] = []
    @State private var currentIndex = 0
    @State private var isPlaying = false
    @State private var timer: Timer?
    @AppStorage("readingSpeed") private var wpm: Double = 300
    @State private var pauseTicks = 0
    
    // UI State
    @State private var showJumpToPage = false
    @State private var jumpToPageNumber = 1.0
    
    var body: some View {
        VStack {
            // Header: Chapter and Page Info
            VStack(spacing: 4) {
                Text(chapterTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                if let currentWord = words[safe: currentIndex] {
                    Text("Page \(currentWord.pageIndex + 1) of \(pages.count)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .onTapGesture {
                            jumpToPageNumber = Double(currentWord.pageIndex + 1)
                            showJumpToPage = true
                        }
                }
            }
            .padding(.top)
            
            if !words.isEmpty && currentIndex < words.count {
                Spacer()
                
                Text(words[currentIndex].text)
                    .font(.system(size: 48, weight: .bold))
                    .multilineTextAlignment(.center)
                    .onTapGesture {
                        togglePlay()
                    }
                
                Spacer()
                
                // Estimated Time Remaining
                Text(calculateRemainingTime())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                
                // Progress
                ProgressView(value: Double(currentIndex), total: Double(words.count))
                    .padding(.horizontal)
                
                // Controls
                controlsView
                
            } else {
                Text("No text to read.")
            }
        }
        .onAppear {
            prepareText()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: wpm) { _, _ in
            if isPlaying {
                startTimer()
            }
        }
        // Keyboard Handling
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.space) {
            togglePlay()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            skip(by: -10)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            skip(by: 10)
            return .handled
        }
        .onKeyPress(KeyEquivalent("d")) {
            wpm = min(1000, wpm + 50)
            return .handled
        }
        .onKeyPress(KeyEquivalent("s")) {
            wpm = max(50, wpm - 50)
            return .handled
        }
        .sheet(isPresented: $showJumpToPage) {
            jumpToPageView
        }
    }
    
    private var jumpToPageView: some View {
        VStack(spacing: 20) {
            Text("Jump to Page")
                .font(.headline)
            
            Text("Page \(Int(jumpToPageNumber))")
                .font(.title2)
                .bold()
            
            Slider(value: $jumpToPageNumber, in: 1...Double(pages.count), step: 1)
                .padding()
            
            Button("Go") {
                jumpToPage(Int(jumpToPageNumber) - 1)
                showJumpToPage = false
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(minWidth: 300)
    }
    
    private var controlsView: some View {
        VStack {
            HStack {
                Button(action: { skip(by: -10) }) {
                    Image(systemName: "gobackward.10")
                }
                
                Button(action: togglePlay) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                }
                
                Button(action: { skip(by: 10) }) {
                    Image(systemName: "goforward.10")
                }
            }
            .padding()
            
            HStack {
                Text("Speed: \(Int(wpm)) WPM")
                Slider(value: $wpm, in: 50...1000, step: 25)
            }
            .padding()
        }
    }
    
    // ... rest of init ...

    private func calculateRemainingTime() -> String {
        // Calculate ticks (1 tick = 60/wpm seconds)
        // Each word is 1 tick + any pause ticks
        var totalTicks = 0
        
        for i in currentIndex..<words.count {
            totalTicks += 1 // The word itself
            
            let word = words[i].text
            if word.hasSuffix(".") || word.hasSuffix("?") || word.hasSuffix("!") {
                totalTicks += 2
            } else if word.hasSuffix(",") || word.hasSuffix(";") || word.hasSuffix(":") {
                totalTicks += 1
            }
        }
        
        let secondsPerTick = 60.0 / wpm
        let totalSeconds = Double(totalTicks) * secondsPerTick
        
        let mm = Int(totalSeconds) / 60
        let ss = Int(totalSeconds) % 60
        return String(format: "Remaining: %02d:%02d", mm, ss)
    }
    
    private func prepareText() {
        var allWords: [WordItem] = []
        for (pageIndex, pageText) in pages.enumerated() {
            let pageWords = pageText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            for word in pageWords {
                allWords.append(WordItem(text: word, pageIndex: pageIndex))
            }
        }
        self.words = allWords
        
        // Reset only if completely new, otherwise try to keep position?
        // For simple init, reset.
        if currentIndex >= allWords.count {
            currentIndex = 0
        }
        pauseTicks = 0
    }
    
    private func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            startTimer()
        } else {
            stopTimer()
        }
    }
    
    private func skip(by amount: Int) {
        currentIndex = max(0, min(words.count - 1, currentIndex + amount))
        // If jumping, pause briefly maybe? Or just continue
    }
    
    private func jumpToPage(_ pageIndex: Int) {
        // Find first word of that page
        if let index = words.firstIndex(where: { $0.pageIndex == pageIndex }) {
            currentIndex = index
        }
    }
    
    private func startTimer() {
        stopTimer()
        let interval = 60.0 / wpm
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            if pauseTicks > 0 {
                pauseTicks -= 1
                return
            }
            
            if currentIndex < words.count - 1 {
                currentIndex += 1
                
                let currentWord = words[currentIndex].text
                if currentWord.hasSuffix(".") || currentWord.hasSuffix("?") || currentWord.hasSuffix("!") {
                    pauseTicks = 2
                } else if currentWord.hasSuffix(",") || currentWord.hasSuffix(";") || currentWord.hasSuffix(":") {
                    pauseTicks = 1
                }
            } else {
                isPlaying = false
                stopTimer()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    

}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
