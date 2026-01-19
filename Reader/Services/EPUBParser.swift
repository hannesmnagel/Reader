//
//  EPUBParser.swift
//  Reader
//
//  Created by Hannes Nagel on 1/17/26.
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

class EPUBParser {
    
    static func extractText(from data: Data) -> [String] {
        guard let zip = ZipUtils(data: data) else {
            return ["Error: Invalid EPUB or Zip Archive"]
        }
        
        // 1. Find Container (META-INF/container.xml)
        // EPUB standard requires this exact path.
        guard let containerData = zip.data(for: "META-INF/container.xml") else {
            return ["Error: Invalid EPUB (Missing container.xml)"]
        }
        
        let containerParser = ContainerParser()
        let parser = XMLParser(data: containerData)
        parser.delegate = containerParser
        parser.parse()
        
        guard let opfPath = containerParser.opfPath else {
            return ["Error: Invalid EPUB (No rootfile found)"]
        }
        
        // 2. Parse OPF to get file structure
        guard let opfData = zip.data(for: opfPath) else {
            return ["Error: Invalid EPUB (Missing OPF file at \(opfPath))"]
        }
        
        let opfParser = OPFParser()
        let xmlParser = XMLParser(data: opfData)
        xmlParser.delegate = opfParser
        xmlParser.parse()
        
        // 3. Extract Text from Spines
        var pages: [String] = []
        
        // Resolve paths relative to OPF file location
        // Example: if opf is "OEBPS/content.opf" and href is "text/ch01.html" -> "OEBPS/text/ch01.html"
        let opfURL = URL(fileURLWithPath: opfPath)
        let opfBaseURL = opfURL.deletingLastPathComponent()
        
        for idRef in opfParser.spine {
            if let href = opfParser.manifest[idRef] {
                // Construct full path logic
                // Using URL logic to handle ".." and folders correctly
                let fullURL = opfBaseURL.appendingPathComponent(href)
                // path returns with leading slash usually if strictly file URL, but here we initiated with relative path.
                // relative path "OEBPS/content.opf" -> /OEBPS/content.opf in some contexts?
                // Let's verify string behavior.
                // safest is simple string path if no ".."
                
                var fullPath = fullURL.path
                if fullPath.hasPrefix("/") {
                    fullPath.removeFirst()
                }
                
                // Try to find the entry
                if let htmlData = zip.data(for: fullPath) {
                   if let text = htmlDataToText(htmlData) {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            pages.append(text)
                        }
                    } 
                } else {
                    // Try to decode URI encoded paths if needed?
                    // Some EPUBs have encoded filenames.
                    if let decoded = fullPath.removingPercentEncoding,
                       let htmlData = zip.data(for: decoded) {
                        if let text = htmlDataToText(htmlData) {
                             let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                             if !trimmed.isEmpty {
                                 pages.append(text)
                             }
                         }
                    }
                }
            }
        }
        
        return pages.isEmpty ? ["No text content found."] : pages
    }
    
    private static func htmlDataToText(_ data: Data) -> String? {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        var result: String?
        
        // NSAttributedString HTML import requires main thread on iOS/macOS usually for WebKit
        if Thread.isMainThread {
            if let attr = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
                result = attr.string
            }
        } else {
            DispatchQueue.main.sync {
                if let attr = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
                    result = attr.string
                }
            }
        }
        
        return result
    }
}

// MARK: - XML Parsers
// Reusing same classes

class ContainerParser: NSObject, XMLParserDelegate {
    var opfPath: String?
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "rootfile", let path = attributeDict["full-path"] {
             // Take first rootfile or check media-type
             if opfPath == nil {
                 opfPath = path
             }
        }
    }
}

class OPFParser: NSObject, XMLParserDelegate {
    var manifest: [String: String] = [:]
    var spine: [String] = []
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "item" {
            if let id = attributeDict["id"], let href = attributeDict["href"] {
                manifest[id] = href
            }
        } else if elementName == "itemref" {
            if let idref = attributeDict["idref"] {
                spine.append(idref)
            }
        }
    }
}
