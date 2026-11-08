//
//  VehicleDocument.swift
//  SerbianVehicleKit
//
//  Decoded contents of a Serbian vehicle registration card (saobraćajna dozvola).
//  Field names follow the official eVehicleRegistration API. Tag paths ported from
//  bas-celik (github.com/ubavic/bas-celik, MIT).
//

import Foundation

public struct VehicleDocument: Codable, Equatable, Sendable {
    // Vehicle identity
    public var registrationNumberOfVehicle = ""
    public var dateOfFirstRegistration = ""
    public var vehicleIdNumber = ""            // VIN
    public var yearOfProduction = ""
    public var vehicleMake = ""
    public var vehicleType = ""
    public var commercialDescription = ""
    public var vehicleCategory = ""
    public var colourOfVehicle = ""
    public var serialNumber = ""

    // Document validity / issuance
    public var issuingDate = ""
    public var expiryDate = ""
    public var typeApprovalNumber = ""
    public var unambiguousNumber = ""
    public var stateIssuing = ""
    public var competentAuthority = ""
    public var authorityIssuing = ""

    // Technical
    public var vehicleMass = ""
    public var maximumPermissibleLadenMass = ""
    public var vehicleLoad = ""
    public var powerWeightRatio = ""
    public var engineCapacity = ""
    public var maximumNetPower = ""
    public var typeOfFuel = ""
    public var engineIdNumber = ""
    public var numberOfAxles = ""
    public var numberOfSeats = ""
    public var numberOfStandingPlaces = ""

    // Owner
    public var ownersSurnameOrBusinessName = ""
    public var ownerName = ""
    public var ownerAddress = ""
    public var ownersPersonalNo = ""

    // User (if different from owner)
    public var usersSurnameOrBusinessName = ""
    public var usersName = ""
    public var usersAddress = ""
    public var usersPersonalNo = ""

    public init() {}

    /// Builds a document from a merged BER tree (the four card files combined).
    public init(ber: BER) {
        func setString(_ keyPath: WritableKeyPath<VehicleDocument, String>, _ path: [UInt32]) {
            if let bytes = ber.access(path) {
                let data = Data(bytes)
                self[keyPath: keyPath] = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1) ?? ""
            }
        }
        func set(_ keyPath: WritableKeyPath<VehicleDocument, String>, _ path: UInt32...) {
            setString(keyPath, path)
        }

        set(\.registrationNumberOfVehicle, 0x71, 0x81)
        set(\.dateOfFirstRegistration, 0x71, 0x82)
        set(\.vehicleIdNumber, 0x71, 0x8A)
        set(\.vehicleMass, 0x71, 0x8C)
        set(\.expiryDate, 0x71, 0x8D)
        set(\.issuingDate, 0x71, 0x8E)
        set(\.typeApprovalNumber, 0x71, 0x8F)
        set(\.powerWeightRatio, 0x71, 0x93)
        set(\.vehicleMake, 0x71, 0xA3, 0x87)
        set(\.vehicleType, 0x71, 0xA3, 0x88)
        set(\.commercialDescription, 0x71, 0xA3, 0x89)
        set(\.maximumPermissibleLadenMass, 0x71, 0xA4, 0x8B)
        set(\.engineCapacity, 0x71, 0xA5, 0x90)
        set(\.maximumNetPower, 0x71, 0xA5, 0x91)
        set(\.typeOfFuel, 0x71, 0xA5, 0x92)
        set(\.numberOfSeats, 0x71, 0xA6, 0x94)
        set(\.numberOfStandingPlaces, 0x71, 0xA6, 0x95)
        set(\.stateIssuing, 0x71, 0x9F33)
        set(\.competentAuthority, 0x71, 0x9F35)
        set(\.authorityIssuing, 0x71, 0x9F36)
        set(\.unambiguousNumber, 0x71, 0x9F38)

        set(\.vehicleCategory, 0x72, 0x98)
        set(\.numberOfAxles, 0x72, 0x99)
        set(\.vehicleLoad, 0x72, 0xC4)
        set(\.yearOfProduction, 0x72, 0xC5)
        set(\.engineIdNumber, 0x72, 0xA5, 0x9E)
        set(\.serialNumber, 0x72, 0xC9)
        set(\.colourOfVehicle, 0x72, 0x9F24)
        set(\.usersPersonalNo, 0x72, 0xC3)
        set(\.ownersPersonalNo, 0x72, 0xC2)

        set(\.ownersSurnameOrBusinessName, 0x71, 0xA1, 0xA2, 0x83)
        set(\.ownerName, 0x71, 0xA1, 0xA2, 0x84)
        set(\.ownerAddress, 0x71, 0xA1, 0xA2, 0x85)

        setString(\.usersSurnameOrBusinessName, [0x71, 0xA1, 0xA9, 0x83])
        setString(\.usersName, [0x71, 0xA1, 0xA9, 0x84])
        setString(\.usersAddress, [0x71, 0xA1, 0xA9, 0x85])
        if usersName.isEmpty && usersSurnameOrBusinessName.isEmpty && usersAddress.isEmpty {
            setString(\.usersSurnameOrBusinessName, [0x72, 0xA1, 0xA9, 0x83])
            setString(\.usersName, [0x72, 0xA1, 0xA9, 0x84])
            setString(\.usersAddress, [0x72, 0xA1, 0xA9, 0x85])
        }
    }
}
