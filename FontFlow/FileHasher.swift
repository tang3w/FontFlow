//
//  FileHasher.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Foundation
import CryptoKit

/// Utility for computing file content hashes.
nonisolated struct FileHasher: Sendable {

    enum HashError: Error, Equatable {
        case unreadableFile(URL)
    }

    /// Returns the SHA-256 hex digest of the file at the given URL.
    static func sha256(of url: URL) throws -> String {
        guard let data = try? Data(contentsOf: url) else {
            throw HashError.unreadableFile(url)
        }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
