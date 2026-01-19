//
//  ContentExtractor.swift
//  Reader
//
//  Created by Hannes Nagel on 1/17/26.
//

import Foundation
import UniformTypeIdentifiers
import PDFKit
import Vision

struct ContentExtractor {
    static func extractText(from data: Data, type: UTType) -> [String] {
        if type.conforms(to: .pdf) {
            return extractPDFText(from: data)
        } else if type.conforms(to: UTType("org.idpf.epub-container") ?? .epub) {
            return EPUBParser.extractText(from: data)
        } else if type.conforms(to: .plainText) {
            if let text = String(data: data, encoding: .utf8) {
                return [text]
            }
            return ["Unable to read text file."]
        }
        return ["Unsupported file type."]
    }
    
    private static func extractPDFText(from data: Data) -> [String] {
        guard let pdfDocument = PDFDocument(data: data) else { return [] }
        
        var pagesText: [String] = []
        let pageCount = pdfDocument.pageCount
        
        for index in 0..<pageCount {
            guard let page = pdfDocument.page(at: index) else {
                pagesText.append("") 
                continue 
            }
            
            if let text = page.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pagesText.append(text)
            } else {
                // Fallback to OCR
                pagesText.append(extractTextViaOCR(from: page))
            }
        }
        
        return pagesText
    }
    
    private static func extractTextViaOCR(from page: PDFPage) -> String {
        // Create an image from the page
        let pageRect = page.bounds(for: .mediaBox)
        
        #if os(iOS)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let image = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            
            ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        guard let cgImage = image.cgImage else { return "" }
        #elseif os(macOS)
        let width = Int(pageRect.width)
        let height = Int(pageRect.height)
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) 
        else { return "" }
        
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(CGRect(origin: .zero, size: pageRect.size))
        
        context.saveGState()
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
        
        guard let cgImage = context.makeImage() else { return "" }
        #endif
        
        var recognizedText = ""
        let request = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            // "accurate" recognition level usually handles columns well by returning blocks
            // We join them with newlines or spaces.
            // For a speed reader, we want flow.
            
            let pageText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: " ")
            
            recognizedText = pageText
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        
        return recognizedText
    }
}
