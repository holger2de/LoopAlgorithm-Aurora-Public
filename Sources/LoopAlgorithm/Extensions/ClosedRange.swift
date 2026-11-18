public extension ClosedRange where Bound == LoopQuantity {
    func averageValue(for unit: LoopUnit) -> Double {
        let minValue = lowerBound.doubleValue(for: unit)
        let maxValue = upperBound.doubleValue(for: unit)
        return (maxValue + minValue) / 2
    }
}
