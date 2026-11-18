import Foundation

public enum DoseRecommendationType: String {
    case manualBolus
    case automaticBolus
    case tempBasal

    var automated: Bool {
        switch self {
        case .automaticBolus,
             .tempBasal:
            return true
        case .manualBolus:
            return false
        }
    }
}
