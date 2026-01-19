
import XCTest
import UniformTypeIdentifiers
@testable import Reader

final class PDFExtractionTests: XCTestCase {

    func testAnimalFarmExtraction() throws {
        // Absolute path to the file on the user's desktop
        let filePath = "/Users/hannesnagel/Desktop/Reader/Animal-Farm-Full-Book.pdf"
        let fileURL = URL(fileURLWithPath: filePath)
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            XCTFail("Test file not found at \(filePath). Please ensure the file is present.")
            return
        }
        
        let data = try Data(contentsOf: fileURL)
        
        // Measure performance if desired, but here we just check correctness
        let startTime = Date()
        print("Starting extraction...")
        
        let text = ContentExtractor.extractText(from: data, type: .pdf)
        
        let duration = Date().timeIntervalSince(startTime)
        print("Extraction took \(duration) seconds")
        
        // Assertions
        XCTAssertFalse(text.isEmpty, "Extracted text should not be empty")
        
        // Check for specific content known to be in the book
        // "Introduction", "Animal Farm", "George Orwell" etc.
        let lowText = text.lowercased()
        
        // Use loose matching as OCR might not be perfect
        let hasTitle = lowText.contains("animal farm")
        let hasIntro = lowText.contains("introduction")
        
        XCTAssertTrue(hasTitle || hasIntro, "Text should contain 'Animal Farm' or 'Introduction'. Found start of text: \(text.prefix(200))")
        
        // Check length to ensure we got a significant amount of text
        XCTAssertGreaterThan(text.count, 1000, "Should extract a substantial amount of text from the book")
    }
}
