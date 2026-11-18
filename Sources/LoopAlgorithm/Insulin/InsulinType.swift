import Foundation

public enum FixtureInsulinType: String, Codable, CaseIterable {
    case novolog
    case humalog
    case apidra
    case fiasp
    case lyumjev
    case afrezza

    var insulinModel: InsulinModel {
        switch self {
        case .fiasp:
            return ExponentialInsulinModelPreset.fiasp
        case .lyumjev:
            return ExponentialInsulinModelPreset.lyumjev
        case .afrezza:
            return ExponentialInsulinModelPreset.afrezza
        default:
            return ExponentialInsulinModelPreset.rapidActingAdult
        }
    }
}
