import CoreGraphics

struct ShimmerLayoutMetrics {
    let gradientWidth: CGFloat
    let offsetX: CGFloat

    static func make(width: CGFloat, phase: CGFloat) -> ShimmerLayoutMetrics? {
        guard width.isFinite, phase.isFinite, width > 0 else {
            return nil
        }

        return ShimmerLayoutMetrics(
            gradientWidth: width * 2,
            offsetX: -width + phase * width * 3
        )
    }
}
