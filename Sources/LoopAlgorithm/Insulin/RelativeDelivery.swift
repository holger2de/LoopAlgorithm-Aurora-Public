import Foundation

public enum BasalRelativeDoseType: Equatable {
    case bolus
    case basal(scheduledRate: Double)
}

public struct BasalRelativeDose: TimelineValue {
    public var type: BasalRelativeDoseType
    public var startDate: Date
    public var endDate: Date
    public var volume: Double
    public var insulinModel: InsulinModel

    public var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    public init(
        type: BasalRelativeDoseType,
        startDate: Date,
        endDate: Date,
        volume: Double,
        insulinModel: InsulinModel = ExponentialInsulinModelPreset.rapidActingAdult
    ) {
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.volume = volume
        self.insulinModel = insulinModel
    }
}

public extension BasalRelativeDose {
    /// The number of units delivered, net the basal rate scheduled during that time, which can be used to compute insulin on-board and glucose effects
    var netBasalUnits: Double {
        if case let .basal(scheduledRate) = type {
            guard duration.hours > 0 else {
                return 0
            }
            let scheduledUnits = scheduledRate * duration.hours
            return volume - scheduledUnits
        } else {
            return volume
        }
    }
}

extension BasalRelativeDose: InsulinDose {
    public var deliveryType: InsulinDeliveryType {
        switch type {
        case .basal:
            return .basal
        case .bolus:
            return .bolus
        }
    }
}

extension BasalRelativeDose {
    static func fromBolus(dose: InsulinDose) -> BasalRelativeDose {
        precondition(dose.deliveryType == .bolus, "Dose passed to fromBolus() must be a bolus.")

        return BasalRelativeDose(
            type: .bolus,
            startDate: dose.startDate,
            endDate: dose.endDate,
            volume: dose.volume,
            insulinModel: dose.insulinModel
        )
    }
}

extension BasalRelativeDoseType: Codable {}

extension BasalRelativeDose: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(BasalRelativeDoseType.self, forKey: .type)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        volume = try container.decode(Double.self, forKey: .volume)
        // Not encoded atm. Could at some point define some "fixture" models"
        insulinModel = ExponentialInsulinModelPreset.rapidActingAdult.model
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(volume, forKey: .volume)
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case startDate
        case endDate
        case volume
    }
}
