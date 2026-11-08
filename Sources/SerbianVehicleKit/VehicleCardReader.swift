//
//  VehicleCardReader.swift
//  SerbianVehicleKit
//
//  Reads a Serbian vehicle registration card (saobraćajna dozvola) over a contact
//  reader using CryptoTokenKit (TKSmartCard), iOS 16+ / macOS 13+.
//
//  Applet-selection sequence and file layout ported from bas-celik
//  (github.com/ubavic/bas-celik, MIT) `card/vehicle.go`.
//

import Foundation
import CryptoTokenKit

public enum VehicleError: Error, CustomStringConvertible, Sendable {
    case noReader
    case unsupportedCard
    case apduFailed(statusWord: String, context: String)
    case transport(String)
    case parsing(String)

    public var description: String {
        switch self {
        case .noReader: return "No card reader or slot is available."
        case .unsupportedCard: return "The inserted card is not a Serbian vehicle card."
        case .apduFailed(let sw, let ctx): return "APDU failed [\(ctx)] SW=\(sw)"
        case .transport(let m): return "Transport error: \(m)"
        case .parsing(let m): return "Parsing error: \(m)"
        }
    }
}

public final class VehicleCardReader {

    private let card: TKSmartCard

    public var onLog: ((String) -> Void)?
    private func log(_ message: String) { onLog?(message) }

    /// Opens the first reader slot that currently holds a card.
    public init(slotName: String? = nil) async throws {
        guard let manager = TKSmartCardSlotManager.default else { throw VehicleError.noReader }
        let names = manager.slotNames
        guard !names.isEmpty else { throw VehicleError.noReader }

        var chosen: TKSmartCard?
        for name in (slotName.map { [$0] } ?? names) {
            guard let slot = await manager.getSlot(withName: name),
                  slot.state == .validCard,
                  let smartCard = slot.makeSmartCard() else { continue }
            chosen = smartCard
            break
        }
        guard let smartCard = chosen else { throw VehicleError.noReader }
        self.card = smartCard
    }

    // MARK: High-level read

    /// Selects the vehicle applet and reads the full document.
    public func readAll() async throws -> VehicleDocument {
        try await card.beginSession()
        defer { card.endSession() }

        try await initCard()

        let root = BER(tag: 0, isPrimitive: false, data: nil, children: [])
        for i in 0..<4 {
            let fid: [UInt8] = [0xD0, UInt8(i) * 0x10 + 0x01]
            log("── Reading file \(TLVHex.string(fid)) ──")
            let bytes = try await readFile(fid)
            do {
                let parsed = try BER.parse(bytes)
                try root.merge(parsed)
            } catch {
                throw VehicleError.parsing("file \(i): \(error)")
            }
        }
        return VehicleDocument(ber: root)
    }

    // MARK: Applet selection (3 reverse-engineered variants)

    private func initCard() async throws {
        let variants: [[[UInt8]]] = [
            [
                [0xA0, 0x00, 0x00, 0x01, 0x51, 0x00, 0x00],
                [0xA0, 0x00, 0x00, 0x00, 0x77, 0x01, 0x08, 0x00, 0x07, 0x00, 0x00, 0xFE, 0x00, 0x00, 0x01, 0x00],
                [0xA0, 0x00, 0x00, 0x00, 0x77, 0x01, 0x08, 0x00, 0x07, 0x00, 0x00, 0xFE, 0x00, 0x00, 0xAD, 0xF2],
            ],
            [
                [0xA0, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00],
                [0xF3, 0x81, 0x00, 0x00, 0x02, 0x53, 0x45, 0x52, 0x56, 0x4C, 0x04, 0x02, 0x01],
                [0xA0, 0x00, 0x00, 0x00, 0x77, 0x01, 0x08, 0x00, 0x07, 0x00, 0x00, 0xFE, 0x00, 0x00, 0xAD, 0xF2],
            ],
            [
                [0xA0, 0x00, 0x00, 0x00, 0x18, 0x43, 0x4D, 0x00],
                [0xA0, 0x00, 0x00, 0x00, 0x18, 0x34, 0x14, 0x01, 0x00, 0x65, 0x56, 0x4C, 0x2D, 0x30, 0x30, 0x31],
                [0xA0, 0x00, 0x00, 0x00, 0x18, 0x65, 0x56, 0x4C, 0x2D, 0x30, 0x30, 0x31],
            ],
        ]

        for (index, variant) in variants.enumerated() {
            if await tryInit(variant) {
                log("✓ vehicle applet selected (variant \(index + 1))")
                return
            }
        }
        throw VehicleError.unsupportedCard
    }

    private func tryInit(_ commands: [[UInt8]]) async -> Bool {
        // First SELECT must succeed (9000); the next two are issued best-effort.
        guard let (_, sw1, sw2) = try? await selectByName(commands[0], p2: 0x00),
              sw1 == 0x90, sw2 == 0x00 else { return false }
        _ = try? await selectByName(commands[1], p2: 0x00)
        _ = try? await selectByName(commands[2], p2: 0x0C)
        return true
    }

    // MARK: File reading

    private func readFile(_ name: [UInt8]) async throws -> [UInt8] {
        try await selectFile(name)

        let header = try await readBinary(offset: 0, length: 0x20)
        let (length, offset) = try parseFileSize(header)

        var out: [UInt8] = []
        var remaining = Int(length)
        var position = Int(offset)
        while remaining > 0 {
            let toRead = min(remaining, 0x64)
            let chunk = try await readBinary(offset: position, length: toRead)
            if chunk.isEmpty { break }
            out.append(contentsOf: chunk)
            position += chunk.count
            remaining -= chunk.count
        }
        return out
    }

    /// Parses the 32-byte file header to find where the BER structure starts and its size.
    private func parseFileSize(_ header: [UInt8]) throws -> (length: UInt32, offset: UInt32) {
        guard header.count >= 2 else { throw VehicleError.parsing("header too short") }
        let offset = Int(header[1]) + 2
        guard offset < header.count else { throw VehicleError.parsing("header offset out of range") }

        do {
            let (_, _, tagLen) = try BER.parseTag(Array(header[offset...]))
            let lenStart = offset + Int(tagLen)
            guard lenStart < header.count else { throw VehicleError.parsing("header length out of range") }
            let (dataLength, lenLen) = try BER.parseLength(Array(header[lenStart...]))
            let total = dataLength + tagLen + lenLen
            return (total, UInt32(offset))
        } catch let e as BERError {
            throw VehicleError.parsing("file header: \(e)")
        }
    }

    // MARK: APDU primitives

    /// SELECT by DF name (applet), used during init: `00 A4 04 <p2> <Lc> <name>`.
    @discardableResult
    private func selectByName(_ name: [UInt8], p2: UInt8) async throws -> (Data, UInt8, UInt8) {
        try await transmit([0x00, 0xA4, 0x04, p2, UInt8(name.count)] + name)
    }

    /// SELECT FILE by identifier: `00 A4 02 04 <Lc> <fid>`.
    @discardableResult
    private func selectFile(_ fid: [UInt8]) async throws -> Data {
        let (data, sw1, sw2) = try await transmit([0x00, 0xA4, 0x02, 0x04, UInt8(fid.count)] + fid)
        guard sw1 == 0x90, sw2 == 0x00 else {
            throw VehicleError.apduFailed(statusWord: TLVHex.string([sw1, sw2]),
                                          context: "selectFile \(TLVHex.string(fid))")
        }
        return data
    }

    /// READ BINARY in chunks of ≤ 255 bytes: `00 B0 <offHi> <offLo> <len>`.
    private func readBinary(offset: Int, length: Int) async throws -> [UInt8] {
        var out: [UInt8] = []
        var off = offset
        var remaining = length
        while remaining > 0 {
            let chunk = min(remaining, 255)
            let apdu: [UInt8] = [0x00, 0xB0, UInt8((off >> 8) & 0xFF), UInt8(off & 0xFF), UInt8(chunk)]
            let (data, sw1, sw2) = try await transmit(apdu)
            guard sw1 == 0x90, sw2 == 0x00 else {
                throw VehicleError.apduFailed(statusWord: TLVHex.string([sw1, sw2]),
                                              context: "readBinary@\(off)")
            }
            if data.isEmpty { break }
            out.append(contentsOf: data)
            off += data.count
            remaining -= data.count
        }
        return out
    }

    private func transmit(_ apdu: [UInt8]) async throws -> (Data, UInt8, UInt8) {
        log("→ APDU  \(TLVHex.string(apdu))")
        let response: Data
        do { response = try await card.transmit(Data(apdu)) }
        catch { log("‼︎ transport: \(error)"); throw VehicleError.transport("\(error)") }
        guard response.count >= 2 else { throw VehicleError.transport("response shorter than 2 bytes") }
        let sw1 = response[response.count - 2]
        let sw2 = response[response.count - 1]
        let body = response.subdata(in: 0..<(response.count - 2))
        log("← \(String(format: "%02X%02X", sw1, sw2)) (\(body.count) bytes)")
        return (body, sw1, sw2)
    }
}

enum TLVHex {
    static func string(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined()
    }
}
