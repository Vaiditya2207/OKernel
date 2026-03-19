import XCTest
import CryptoKit
@testable import AetherApp

final class UpdateManagerTests: XCTestCase {
    func testSignatureVerification() {
        let manager = UpdateManager.shared
        let testData = "Hello Aether Update".data(using: .utf8)!
        
        // Generate a temporary key for testing since we don't have the private key of the embedded pubkey
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        let signature = try! privateKey.signature(for: testData)
        
        // Test that CryptoKit works as expected
        XCTAssertTrue(publicKey.isValidSignature(signature, for: testData))
        
        // Test with a tampered data
        let tamperedData = "Hello Aether Tampered".data(using: .utf8)!
        XCTAssertFalse(publicKey.isValidSignature(signature, for: tamperedData))
    }
    
    func testHexDataExtension() {
        let hex = "48656c6c6f" // "Hello"
        let data = Data(hexString: hex)
        XCTAssertEqual(String(data: data, encoding: .utf8), "Hello")
    }
    
    func testVersionInfoEncoding() {
        let json = """
        {
            "version": "0.4.0",
            "description": "Test Update",
            "changelog": "Bug fixes",
            "release_date": "2026-03-19T12:00:00Z",
            "size": 12345,
            "bundle_filename": "Aether-0.4.0.tar.gz",
            "bundle_size": 10000,
            "channel": "stable"
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        XCTAssertNoThrow(try decoder.decode(AetherVersionInfo.self, from: json))
    }
}
