import Foundation

public struct LoopAlgorithmDoseRecommendation: Equatable {
    public var manual: ManualBolusRecommendation?
    public var automatic: AutomaticDoseRecommendation?

    public init(manual: ManualBolusRecommendation? = nil, automatic: AutomaticDoseRecommendation? = nil) {
        self.manual = manual
        self.automatic = automatic
    }
}

extension LoopAlgorithmDoseRecommendation: Codable {}
