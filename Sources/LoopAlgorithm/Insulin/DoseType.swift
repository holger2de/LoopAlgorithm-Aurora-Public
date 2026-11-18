import Foundation

/// A general set of ways insulin can be delivered by a pump
public enum InsulinDeliveryType: String, CaseIterable, Equatable {
    case bolus
    case basal
}

extension InsulinDeliveryType: Codable {}
