import XCTest
@testable import ips2crashlog

final class IPS2CrashLogTests: XCTestCase {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ips2crashlog_tests")
    
    override func setUp() {
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testConversion() throws {
        // Get test resource paths
        let bundle = Bundle.module
        guard let sourcePath = bundle.path(forResource: "source", ofType: "ips"),
              let targetPath = bundle.path(forResource: "target", ofType: "txt") else {
            XCTFail("Could not find test resources")
            return
        }
        
        // Set up output path
        let outputPath = tempDir.appendingPathComponent("output.crash").path
        
        // Run conversion
        let converter = IPSConverter()
        try converter.convert(inputPath: sourcePath, outputPath: outputPath)
        
        // Compare results
        let expectedOutput = try String(contentsOfFile: targetPath)
        let actualOutput = try String(contentsOfFile: outputPath)
        
        // Check line by line
        let expectedLines = expectedOutput.components(separatedBy: .newlines)
        let actualLines = actualOutput.components(separatedBy: .newlines)

        var failedLines = 0
        var lineIndex = 0
        for (expected, actual) in zip(expectedLines, actualLines) {
            XCTAssertEqual(expected, actual, "Line \(lineIndex) does not match")
            lineIndex += 1

            if expected != actual {
                print("Expected: \(expected)")
                print("  Actual: \(actual)")
                
                failedLines += 1
            }

            if failedLines > 5 {
                XCTFail("Too many failed lines")
                break
            }
        }
    }
    
    func testDefaultOutputPath() throws {
        let bundle = Bundle.module
        guard let sourcePath = bundle.path(forResource: "source", ofType: "ips") else {
            XCTFail("Could not find test resources")
            return
        }
        
        // Copy source to temp directory for testing
        let tempSource = tempDir.appendingPathComponent("test.ips")
        try FileManager.default.copyItem(at: URL(fileURLWithPath: sourcePath), to: tempSource)
        
        // Run conversion with default output path
        let converter = IPSConverter()
        try converter.convert(inputPath: tempSource.path, outputPath: nil)
        
        // Verify .crash file was created
        let expectedOutput = tempSource.deletingPathExtension().appendingPathExtension("crash")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedOutput.path), "Should create .crash file at default location")
    }
}