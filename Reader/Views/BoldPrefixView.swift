//
//  BoldPrefixView.swift
//  Reader
//
//  Created by Hannes Nagel on 1/17/26.
//

import SwiftUI

struct BoldPrefixView: View {
    let text: String
    var onToggleFullScreen: () -> Void = {}
    
    var body: some View {
        ScrollView {
            Text(attributedText)
                .font(.body)
                .padding(.horizontal, 8)
                .padding(.top)
                .onTapGesture {
                    onToggleFullScreen()
                }
        }
    }
    
    private var attributedText: AttributedString {
        var combined = AttributedString("")
        
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        
        for (index, word) in words.enumerated() {
            if word.isEmpty { continue }
            
            // Bold the first half (or reasonable prefix) of the word
            let prefixLength = max(1, Int(ceil(Double(word.count) * 0.4)))
            let prefixIndex = word.index(word.startIndex, offsetBy: prefixLength)
            let prefix = String(word[..<prefixIndex])
            let suffix = String(word[prefixIndex...])
            
            var prefixAttr = AttributedString(prefix)
            prefixAttr.font = .body.bold()
            prefixAttr.foregroundColor = .primary
            
            var suffixAttr = AttributedString(suffix)
            // Lighter and condensed as requested
            suffixAttr.font = Font.system(.body).width(.condensed).weight(.light)
            suffixAttr.foregroundColor = .secondary.opacity(0.8)
            
            combined.append(prefixAttr)
            combined.append(suffixAttr)
            
            if index < words.count - 1 {
                combined.append(AttributedString(" "))
            }
        }
        
        return combined
    }
}
