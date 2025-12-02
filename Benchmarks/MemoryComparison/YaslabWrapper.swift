//
// YaslabWrapper.swift
// MemoryComparison
//
// Wrapper to isolate yaslab's ULID import from FastULID
//

import Foundation
import ULID

/// Wrapper for yaslab's ULID to avoid naming conflicts
public struct YaslabWrapper {
    // ULID module exports a struct called ULID
    // When imported, it's just called ULID in this file's scope
    public typealias ULIDType = ULID
    
    public static func createULID() -> ULID {
        return ULID()
    }
    
    public static func createULID(ulidString: String) throws -> ULID {
        guard let ulid = ULID(ulidString: ulidString) else {
            throw NSError(domain: "YaslabWrapper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid ULID string"])
        }
        return ulid
    }
    
    public static func ulidString(from ulid: ULID) -> String {
        return ulid.ulidString
    }
}

