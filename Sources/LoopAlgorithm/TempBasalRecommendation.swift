import Foundation

public struct TempBasalRecommendation: Equatable {
    public var unitsPerHour: Double
    public let duration: TimeInterval

    public init(unitsPerHour: Double, duration: TimeInterval) {
        self.unitsPerHour = unitsPerHour
        self.duration = duration
    }
}

extension TempBasalRecommendation: Codable {}
