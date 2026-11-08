# SerbianVehicleKit

[![CI](https://github.com/nenadvulic/SerbianVehicleKit/actions/workflows/ci.yml/badge.svg)](https://github.com/nenadvulic/SerbianVehicleKit/actions/workflows/ci.yml)

A dependency-free Swift package that reads the **Serbian vehicle registration card
(saobraćajna dozvola)** from a contact smart-card reader on **iOS/iPadOS 16+** and
**macOS 13+**, using Apple's [CryptoTokenKit](https://developer.apple.com/documentation/cryptotokenkit)
(`TKSmartCard`).

> ⚖️ For interoperability and research on **your own** documents. The data is personal,
> handle it accordingly.

See also [SerbianEIDKit](https://github.com/nenadvulic/SerbianEIDKit) for the identity card.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/nenadvulic/SerbianVehicleKit.git", from: "1.0.0"),
],
```

Add the **Smart Card** capability to your app target (entitlement `com.apple.security.smartcard`).

## Usage

```swift
import SerbianVehicleKit

let reader = try await VehicleCardReader()
reader.onLog = { print($0) }                 // optional APDU log

let doc = try await reader.readAll()
print(doc.registrationNumberOfVehicle)        // "BG123-AA"
print(doc.vehicleMake, doc.commercialDescription)
print(doc.ownerName, doc.ownersSurnameOrBusinessName)
```

`VehicleDocument` is `Codable`, so it serializes to clean JSON (backend, caching, tests).

## How the card is read

The vehicle card is an ISO 7816-4 contact chip, but its data model differs from the ID card:
it uses **standard nested BER-TLV** (ASN.1), not the ID card's proprietary little-endian TLV.

1. **Select the applet**: a three-command sequence (`SELECT` by DF name), tried in three
   variants to cover different card generations.
2. **Read four files**, `D001`, `D011`, `D021`, `D031`:
   - `SELECT FILE` `00 A4 02 04 <fid>`,
   - read a **32-byte header**, whose BER tag/length give where the structure starts and its size,
   - `READ BINARY` the body in blocks of ≤ 100 bytes.
3. **Parse BER-TLV** and **merge** the four files into one tree.
4. **Extract fields** by their tag path, e.g. the make is at `71 → A3 → 87`, the VIN at `71 → 8A`,
   the owner's name at `71 → A1 → A2 → 84`.

### Some fields

| Field | Tag path |
|-------|----------|
| registration number | `71 81` |
| VIN | `71 8A` |
| make | `71 A3 87` |
| commercial description | `71 A3 89` |
| engine capacity | `71 A5 90` |
| fuel type | `71 A5 92` |
| owner surname / business | `71 A1 A2 83` |
| owner name | `71 A1 A2 84` |
| owner address | `71 A1 A2 85` |
| vehicle category | `72 98` |
| year of production | `72 C5` |

(The full set is in `VehicleDocument`.)

## Hardware notes

- Requires a **CCID** contact reader. On iPhone 15+/iPad (USB-C) a USB-C reader connects directly;
  a USB reader works via a USB-C adapter (a powered hub helps for power-hungry readers).
- Does **not** work on the iOS Simulator (`TKSmartCardSlotManager.default` is `nil`).

## Example app

[`Examples/VehicleReaderDemo`](Examples/VehicleReaderDemo) is a minimal SwiftUI app: tap
**Read card** to show the fields and the APDU log.

## Credits

The vehicle protocol (applet selection, file layout, BER-TLV parsing, tag paths) was ported
from [bas-celik](https://github.com/ubavic/bas-celik) by Nikola Ubavić (MIT). Many thanks.

## License

MIT. See [LICENSE](LICENSE).
