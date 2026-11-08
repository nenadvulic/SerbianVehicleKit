//
//  SerbianTransliteration.swift
//  SerbianVehicleKit
//
//  Serbian Cyrillic → Latin (Gaj's Latin) transliteration.
//
//  Note: vehicle cards observed so far store their data already in Latin, so this is
//  effectively a no-op for them. It is provided for consistency and as a safety net in
//  case a card stores Cyrillic. Text already in Latin passes through unchanged.
//

import Foundation

public enum SerbianTransliteration {

    private static let map: [Character: String] = [
        "А": "A", "Б": "B", "В": "V", "Г": "G", "Д": "D", "Ђ": "Đ", "Е": "E",
        "Ж": "Ž", "З": "Z", "И": "I", "Ј": "J", "К": "K", "Л": "L", "Љ": "Lj",
        "М": "M", "Н": "N", "Њ": "Nj", "О": "O", "П": "P", "Р": "R", "С": "S",
        "Т": "T", "Ћ": "Ć", "У": "U", "Ф": "F", "Х": "H", "Ц": "C", "Ч": "Č",
        "Џ": "Dž", "Ш": "Š",
        "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "ђ": "đ", "е": "e",
        "ж": "ž", "з": "z", "и": "i", "ј": "j", "к": "k", "л": "l", "љ": "lj",
        "м": "m", "н": "n", "њ": "nj", "о": "o", "п": "p", "р": "r", "с": "s",
        "т": "t", "ћ": "ć", "у": "u", "ф": "f", "х": "h", "ц": "c", "ч": "č",
        "џ": "dž", "ш": "š",
    ]

    /// Transliterates Serbian Cyrillic to Latin. Non-Cyrillic characters pass through.
    /// Uppercase digraphs expand correctly in all-caps context ("ЊЕГОШ" → "NJEGOŠ").
    public static func toLatin(_ string: String) -> String {
        let characters = Array(string)
        var result = ""
        for (index, character) in characters.enumerated() {
            guard let mapped = map[character] else {
                result.append(character)
                continue
            }
            if mapped.count == 2, character.isUppercase {
                let next = index + 1 < characters.count ? characters[index + 1] : nil
                let allCaps = next == nil || next!.isUppercase || !next!.isLetter
                result += allCaps ? mapped.uppercased() : mapped
            } else {
                result += mapped
            }
        }
        return result
    }
}

public extension VehicleDocument {
    /// A copy of the document with every string field transliterated to Latin.
    /// (No-op for cards that already store Latin data.)
    func latinized() -> VehicleDocument {
        var copy = self
        let t = SerbianTransliteration.toLatin
        copy.registrationNumberOfVehicle = t(registrationNumberOfVehicle)
        copy.vehicleMake = t(vehicleMake)
        copy.vehicleType = t(vehicleType)
        copy.commercialDescription = t(commercialDescription)
        copy.colourOfVehicle = t(colourOfVehicle)
        copy.typeOfFuel = t(typeOfFuel)
        copy.ownersSurnameOrBusinessName = t(ownersSurnameOrBusinessName)
        copy.ownerName = t(ownerName)
        copy.ownerAddress = t(ownerAddress)
        copy.usersSurnameOrBusinessName = t(usersSurnameOrBusinessName)
        copy.usersName = t(usersName)
        copy.usersAddress = t(usersAddress)
        copy.competentAuthority = t(competentAuthority)
        copy.authorityIssuing = t(authorityIssuing)
        return copy
    }
}
