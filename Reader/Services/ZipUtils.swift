//
//  ZipUtils.swift
//  Reader
//
//  Created by Hannes Nagel on 1/17/26.
//

import Foundation

// Attempt to import zlib. If this fails, we need a bridging header or module map.
// In standard iOS/macOS SDK, zlib is a system library and usually importable if a module map is present.
// If this specifically fails, we will need to address it.
import zlib

class ZipUtils {
    
    struct Entry {
        let path: String
        let offset: Int // Offset to Local File Header
        let compressedSize: Int
        let uncompressedSize: Int
        let compressionMethod: UInt16 // 0 = Store, 8 = Deflate
    }
    
    private let data: Data
    private(set) var entries: [String: Entry] = [:]
    
    init?(data: Data) {
        self.data = data
        if !parseCentralDirectory() {
            return nil
        }
    }
    
    func data(for path: String) -> Data? {
        guard let entry = entries[path] else { return nil }
        
        // 1. Read Local File Header at entry.offset
        // Structure:
        // 0-3: Signature (0x04034b50)
        // 4-25: ...
        // 26-27: Name Len
        // 28-29: Extra Len
        // 30...: Name
        // ... Extra
        
        let headerSize = 30
        guard entry.offset + headerSize <= data.count else { return nil }
        
        // Verify signature
        let sig = data.scanValue(at: entry.offset) as UInt32
        if sig != 0x04034b50 { return nil }
        
        let nameLen = Int(data.scanValue(at: entry.offset + 26) as UInt16)
        let extraLen = Int(data.scanValue(at: entry.offset + 28) as UInt16)
        
        let dataStart = entry.offset + headerSize + nameLen + extraLen
        
        guard dataStart + entry.compressedSize <= data.count else { return nil }
        
        let compressedData = data.subdata(in: dataStart..<(dataStart + entry.compressedSize))
        
        if entry.compressionMethod == 0 {
            return compressedData
        } else if entry.compressionMethod == 8 {
            return decompressDeflate(data: compressedData, uncompressedSize: entry.uncompressedSize)
        } else {
            // Unsupported compression
            return nil
        }
    }
    
    // MARK: - Parsing
    
    private func parseCentralDirectory() -> Bool {
        // 1. Find EOCD
        // EOCD (End of Central Directory Record) Signature: 0x06054b50
        // Min size: 22 bytes.
        // It is at the end of the file, possibly followed by a comment.
        // We scan backwards from end-22.
        
        let eocdSig: UInt32 = 0x06054b50
        var eocdOffset = -1
        
        let scanStart = max(0, data.count - 65535 - 22)
        let scanEnd = max(0, data.count - 22)
        
        for i in stride(from: scanEnd, through: scanStart, by: -1) {
             let val = data.scanValue(at: i) as UInt32
             if val == eocdSig {
                 eocdOffset = i
                 break
             }
        }
        
        guard eocdOffset >= 0 else { return false }
        
        // Read EOCD
        // Offset 10: Total entries (UInt16)
        // Offset 12: Size of CD (UInt32)
        // Offset 16: Offset of CD (UInt32)
        
        let cdCount = Int(data.scanValue(at: eocdOffset + 10) as UInt16)
        let cdSize = Int(data.scanValue(at: eocdOffset + 12) as UInt32)
        let cdStart = Int(data.scanValue(at: eocdOffset + 16) as UInt32)
        
        guard cdStart + cdSize <= data.count else { return false }
        
        // Parse Central Directory
        var currentOffset = cdStart
        for _ in 0..<cdCount {
            if currentOffset + 46 > data.count { break }
            
            // CD File Header Signature: 0x02014b50
            let sig = data.scanValue(at: currentOffset) as UInt32
            if sig != 0x02014b50 { break }
            
            let method = data.scanValue(at: currentOffset + 10) as UInt16
            let compressedSize = Int(data.scanValue(at: currentOffset + 20) as UInt32)
            let uncompressedSize = Int(data.scanValue(at: currentOffset + 24) as UInt32)
            let nameLen = Int(data.scanValue(at: currentOffset + 28) as UInt16)
            let extraLen = Int(data.scanValue(at: currentOffset + 30) as UInt16)
            let commentLen = Int(data.scanValue(at: currentOffset + 32) as UInt16)
            let localHeaderOffset = Int(data.scanValue(at: currentOffset + 42) as UInt32)
            
            if let nameData = data.subdata(in: (currentOffset + 46)..<(currentOffset + 46 + nameLen)) as Data?,
               let name = String(data: nameData, encoding: .utf8) {
                
                // Add to entries
                entries[name] = Entry(path: name, offset: localHeaderOffset, compressedSize: compressedSize, uncompressedSize: uncompressedSize, compressionMethod: method)
            }
            
            currentOffset += 46 + nameLen + extraLen + commentLen
        }
        
        return true
    }
    
    // MARK: - Decompression
    
    private func decompressDeflate(data: Data, uncompressedSize: Int) -> Data? {
        // Use zlib raw inflate
        let bufferSize = uncompressedSize
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        var stream = z_stream()
        
        // Initialize for raw deflate (windowBits = -15)
        // Note: ZLIB_VERSION is a C macro string. In Swift we need a way to pass it.
        // Sometimes zlibVersion() function is available.
        
        let initResult = data.withUnsafeBytes { (inputBytes: UnsafeRawBufferPointer) -> Int32 in
            guard let baseAddr = inputBytes.baseAddress else { return Z_STREAM_ERROR }
            
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: baseAddr.assumingMemoryBound(to: Bytef.self))
            stream.avail_in = uInt(inputBytes.count)
            stream.next_out = buffer
            stream.avail_out = uInt(bufferSize)
            stream.zalloc = nil
            stream.zfree = nil
            stream.opaque = nil
            
            // Attempt to use zlibVersion() if imported, or a hardcoded string if needed but that's unsafe.
            // Usually zlibVersion() returns a pointer to version string.
            return inflateInit2_(&stream, -15, zlibVersion(), Int32(MemoryLayout<z_stream>.size))
        }
        
        if initResult != Z_OK { return nil }
        
        let result = inflate(&stream, Z_FINISH)
        let endResult = inflateEnd(&stream)
        
        if result == Z_STREAM_END && endResult == Z_OK {
             return Data(bytes: buffer, count: Int(stream.total_out))
        } else {
            return nil
        }
    }
}

// MARK: - Data Extensions

extension Data {
    func scanValue<T: FixedWidthInteger>(at offset: Int) -> T {
        // Read Little Endian
        let size = MemoryLayout<T>.size
        guard offset + size <= count else { return 0 }
        
        // Copy bytes to value
        // Note: This assumes parsing from byte array.
        return subdata(in: offset..<(offset + size)).withUnsafeBytes { $0.load(as: T.self) }
    }
}

// Helper stride for Swift 5
func instride(from: Int, through: Int, by: Int) -> StrideThrough<Int> {
    return stride(from: from, through: through, by: by)
}
