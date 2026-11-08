//
//  BER.swift
//  SerbianVehicleKit
//
//  Minimal BER-TLV parser (ISO/IEC 7816-4) for the Serbian vehicle card.
//  Unlike the identity card's proprietary little-endian TLV, the vehicle document
//  is encoded as standard, nested BER-TLV.
//
//  Ported from bas-celik (github.com/ubavic/bas-celik, MIT) `card/ber`.
//

import Foundation

public enum BERError: Error, Equatable {
    case invalidLength
    case invalidFormat
    case typeMismatch
    case addIntoPrimitive
}

/// A node (or tree) of a BER structure. Leaf nodes are *primitive* and carry `data`;
/// branch nodes are *constructed* and carry `children`.
public final class BER {
    public let tag: UInt32
    public private(set) var isPrimitive: Bool
    public private(set) var data: [UInt8]?
    public private(set) var children: [BER]

    init(tag: UInt32, isPrimitive: Bool, data: [UInt8]?, children: [BER]) {
        self.tag = tag
        self.isPrimitive = isPrimitive
        self.data = data
        self.children = children
    }

    /// Parses BER-TLV encoded bytes into a tree rooted at a synthetic constructed node (tag 0).
    public static func parse(_ bytes: [UInt8]) throws -> BER {
        let (primitives, constructed) = try parseLayer(bytes)
        let root = BER(tag: 0, isPrimitive: false, data: nil, children: [])
        for (tag, value) in primitives {
            try root.add(BER(tag: tag, isPrimitive: true, data: value, children: []))
        }
        for (tag, value) in constructed {
            let sub = try parse(value)
            try root.add(BER(tag: tag, isPrimitive: false, data: nil, children: sub.children))
        }
        return root
    }

    /// Returns the data located at the given tag path, or `nil` if absent.
    public func access(_ address: [UInt32]) -> [UInt8]? {
        guard let first = address.first else { return data }
        guard let child = children.first(where: { $0.tag == first }) else { return nil }
        return child.access(Array(address.dropFirst()))
    }

    /// Returns the UTF-8 string at the given tag path (ISO-8859-1 fallback), or `nil`.
    public func string(_ address: UInt32...) -> String? {
        guard let bytes = access(address) else { return nil }
        let data = Data(bytes)
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }

    /// Merges another tree (same root tag) into this one.
    public func merge(_ other: BER) throws {
        guard tag == other.tag else { throw BERError.typeMismatch }
        for child in other.children { try add(child) }
    }

    /// Inserts a node, deep-merging constructed nodes that share a tag.
    func add(_ new: BER) throws {
        guard !isPrimitive else { throw BERError.addIntoPrimitive }
        guard let existing = children.first(where: { $0.tag == new.tag }) else {
            children.append(new)
            return
        }
        guard existing.isPrimitive == new.isPrimitive else { throw BERError.typeMismatch }
        if existing.isPrimitive {
            existing.data = new.data
        } else {
            for child in new.children { try existing.add(child) }
        }
    }

    // MARK: - Low-level parsing

    /// Parses one level of BER-TLV, returning primitive and constructed fields by tag.
    static func parseLayer(_ data: [UInt8]) throws -> ([UInt32: [UInt8]], [UInt32: [UInt8]]) {
        var primitives: [UInt32: [UInt8]] = [:]
        var constructed: [UInt32: [UInt8]] = [:]
        var offset = 0
        let count = data.count

        while offset < count {
            let (tag, primitive, tagLen) = try parseTag(Array(data[offset...]))
            offset += Int(tagLen)
            guard offset <= count else { throw BERError.invalidLength }

            let (length, lenLen) = try parseLength(Array(data[offset...]))
            offset += Int(lenLen)

            let end = offset + Int(length)
            guard end <= count else { throw BERError.invalidLength }
            let value = Array(data[offset..<end])

            if primitive { primitives[tag] = value } else { constructed[tag] = value }
            offset = end
        }
        return (primitives, constructed)
    }

    /// Parses a BER tag. Returns (tag, isPrimitive, bytesConsumed).
    static func parseTag(_ data: [UInt8]) throws -> (UInt32, Bool, UInt32) {
        guard let b0 = data.first else { throw BERError.invalidLength }
        let primitive = (b0 & 0x20) == 0
        if (b0 & 0x1F) != 0x1F {
            return (UInt32(b0), primitive, 1)
        } else if data.count >= 2, (data[1] & 0x80) == 0x00 {
            return (UInt32(b0) << 8 | UInt32(data[1]), primitive, 2)
        } else if data.count >= 3 {
            return (UInt32(b0) << 16 | UInt32(data[1]) << 8 | UInt32(data[2]), primitive, 3)
        } else {
            throw BERError.invalidLength
        }
    }

    /// Parses a BER length (ISO 7816-4). Returns (length, bytesConsumed).
    static func parseLength(_ data: [UInt8]) throws -> (UInt32, UInt32) {
        guard let first = data.first.map(UInt32.init) else { throw BERError.invalidLength }
        if first < 0x80 {
            return (first, 1)
        } else if first == 0x80 {
            throw BERError.invalidFormat
        } else if first == 0x81, data.count >= 2 {
            return (UInt32(data[1]), 2)
        } else if first == 0x82, data.count >= 3 {
            return (UInt32(data[1]) << 8 | UInt32(data[2]), 3)
        } else if first == 0x83, data.count >= 4 {
            return (UInt32(data[1]) << 16 | UInt32(data[2]) << 8 | UInt32(data[3]), 4)
        } else if first == 0x84, data.count >= 5 {
            return (UInt32(data[1]) << 24 | UInt32(data[2]) << 16 | UInt32(data[3]) << 8 | UInt32(data[4]), 5)
        } else {
            throw BERError.invalidLength
        }
    }
}
