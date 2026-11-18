import Foundation

// MARK: - Binary search helper

private extension Array {
    /// Returns the index of the first element where `key` > `date` (after: true)
    /// or `key` >= `date` (after: false), using binary search.
    /// Assumes the array is sorted ascending by `key`.
    func partition<K: Comparable>(index date: K, key: KeyPath<Element, K>, after: Bool) -> Int {
        var lo = 0, hi = count
        while lo < hi {
            let mid = (lo + hi) / 2
            let k = self[mid][keyPath: key]
            if after ? k <= date : k < date { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }
}

// MARK: - PrecomputedInsulinInput

/// Pre-annotated insulin data for use in multi-step prediction sweeps.
///
/// **Typical usage — ISF sweep:**
/// ```swift
/// // 1. Annotate once (ISF-independent, reused across all multipliers)
/// let base = PrecomputedInsulinInput.annotate(doses: doses, basal: basal)
///
/// // 2. For each ISF value: compute effects once, sweep all time steps
/// for multiplier in isfMultipliers {
///     let input = base.withEffects(sensitivity: scale(sensitivity, by: multiplier),
///                                  from: sweepStart, to: sweepEnd + activityDuration)
///     for t in sweepSteps {
///         let prediction = LoopAlgorithm.generatePrediction(
///             start: t, glucoseHistory: cgm[t], precomputedInsulin: input, ...)
///     }
/// }
/// ```
///
/// **Note on `Sendable`:** Not conformed because `BasalRelativeDose` stores
/// `any InsulinModel`, a non-Sendable existential.  Sweeps run on a single
/// actor so this is not limiting in practice.
public struct PrecomputedInsulinInput {
    // MARK: - Stored properties

    /// Doses annotated against the scheduled basal timeline.
    ///
    /// ISF-independent — build once with `annotate(doses:basal:)` and reuse
    /// across every ISF multiplier in a sweep.
    public var annotatedDoses: [BasalRelativeDose]

    /// Pre-computed glucose-effect timeline for `annotatedDoses` at a
    /// specific ISF schedule.
    ///
    /// When non-nil, `generatePrediction` uses this directly instead of
    /// calling `glucoseEffects(insulinSensitivityHistory:from:to:)`.
    ///
    /// **ISF sweeps:** rebuild this once per multiplier using `withEffects(sensitivity:)`.
    /// The `annotatedDoses` array is unchanged and does not need to be rebuilt.
    ///
    /// **Timeline coverage:** must cover
    /// `[glucoseHistory.first.startDate, sweepEnd + defaultInsulinActivityDuration]`
    /// for all steps in the sweep.  Pass a generous `to:` date when calling
    /// `withEffects(sensitivity:from:to:)`.
    public var insulinEffects: [GlucoseEffect]?

    // MARK: - Init

    public init(annotatedDoses: [BasalRelativeDose], insulinEffects: [GlucoseEffect]? = nil) {
        self.annotatedDoses = annotatedDoses
        self.insulinEffects = insulinEffects
    }
}

// MARK: - Factory methods

public extension PrecomputedInsulinInput {
    /// **Step 1 of 2 for ISF sweeps.**
    ///
    /// Annotates a full-window dose list against the basal timeline once.
    /// The result can be reused across all ISF multipliers — annotation does
    /// not depend on ISF.
    ///
    /// - Parameters:
    ///   - doses: All insulin doses for the sweep window, sorted by startDate.
    ///   - basal: Scheduled basal timeline covering the same window.
    /// - Returns: A `PrecomputedInsulinInput` with `insulinEffects == nil`.
    ///   Call `withEffects(sensitivity:from:to:)` before passing to
    ///   `generatePrediction`.
    static func annotate<DoseType: InsulinDose>(
        doses: [DoseType],
        basal: [AbsoluteScheduleValue<Double>]
    ) -> PrecomputedInsulinInput {
        PrecomputedInsulinInput(annotatedDoses: doses.annotated(with: basal))
    }

    /// **Step 2 of 2 for ISF sweeps.**
    ///
    /// Computes the glucose-effect timeline for the already-annotated doses
    /// at the given ISF schedule.  Call once per ISF multiplier value; then
    /// pass the result into every `generatePrediction` call for that multiplier.
    ///
    /// - Parameters:
    ///   - sensitivity: The (possibly scaled) ISF timeline for this sweep config.
    ///   - from: Start of the effect timeline.  Defaults to earliest dose start.
    ///     Should be <= `glucoseHistory.first.startDate` for the first eval step.
    ///   - to: End of the effect timeline.  Should cover
    ///     `sweepEnd + defaultInsulinActivityDuration` to avoid truncation at
    ///     the tail of long sweeps.
    ///   - useMidAbsorptionISF: Use mid-absorption ISF computation.
    /// - Returns: A new `PrecomputedInsulinInput` with `insulinEffects` populated.
    func withEffects(
        sensitivity: [AbsoluteScheduleValue<LoopQuantity>],
        from: Date? = nil,
        to: Date? = nil,
        useMidAbsorptionISF: Bool = false
    ) -> PrecomputedInsulinInput {
        let effects: [GlucoseEffect]
        if useMidAbsorptionISF {
            effects = annotatedDoses.glucoseEffectsMidAbsorptionISF(
                insulinSensitivityHistory: sensitivity,
                from: from,
                to: to
            )
        } else {
            effects = annotatedDoses.glucoseEffects(
                insulinSensitivityHistory: sensitivity,
                from: from,
                to: to
            )
        }
        return PrecomputedInsulinInput(annotatedDoses: annotatedDoses, insulinEffects: effects)
    }

    /// Returns a copy with `annotatedDoses` sliced to doses that overlap
    /// `[from, to]`, and `insulinEffects` unchanged (the full pre-built
    /// timeline is always passed through — generatePrediction only reads
    /// the entries it needs).
    ///
    /// Use this per evaluation step to pass only the relevant dose window
    /// into `generatePrediction`, matching what the standard path does when
    /// it calls `doses.annotated(with: basal)` on the per-step slice.
    ///
    /// `annotatedDoses` must be sorted by `startDate`.
    func sliced(from: Date, to: Date) -> PrecomputedInsulinInput {
        // Keep annotated doses that overlap [from, to]:
        //   dose.startDate <= to  AND  dose.endDate > from
        //
        // annotatedDoses is sorted by startDate, so we can binary-search for
        // the upper bound (first startDate > to) and then linear-scan backward
        // from there. For the lower bound we use a linear filter on endDate
        // since the array is NOT sorted by endDate.
        //
        // In practice the dose arrays are small (~100-200 entries per 16h
        // window) so the linear endDate check is negligible.
        let hiIdx = annotatedDoses.partition(index: to, key: \.startDate, after: false)
        let slicedDoses = annotatedDoses[0 ..< hiIdx].filter { $0.endDate > from }
        return PrecomputedInsulinInput(annotatedDoses: slicedDoses, insulinEffects: insulinEffects)
    }

    /// Convenience: annotate and compute effects in one call.
    ///
    /// Use when running a single config (no ISF sweep).  For ISF sweeps,
    /// prefer `annotate(doses:basal:)` + `withEffects(sensitivity:from:to:)`
    /// so annotation cost is paid only once.
    static func build<DoseType: InsulinDose>(
        doses: [DoseType],
        basal: [AbsoluteScheduleValue<Double>],
        sensitivity: [AbsoluteScheduleValue<LoopQuantity>]? = nil,
        effectsFrom: Date? = nil,
        effectsTo: Date? = nil,
        useMidAbsorptionISF: Bool = false
    ) -> PrecomputedInsulinInput {
        let base = annotate(doses: doses, basal: basal)
        guard let sensitivity else { return base }
        return base.withEffects(
            sensitivity: sensitivity,
            from: effectsFrom,
            to: effectsTo,
            useMidAbsorptionISF: useMidAbsorptionISF
        )
    }
}
