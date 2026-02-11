import SwiftUI

struct CloudMidShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: 0.151549 * w, y: 0.610314 * h))
        path.addCurve(
            to: CGPoint(x: 0.223405 * w, y: 0.552087 * h),
            control1: CGPoint(x: 0.164266 * w, y: 0.550100 * h),
            control2: CGPoint(x: 0.195351 * w, y: 0.516066 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.258031 * w, y: 0.543697 * h),
            control1: CGPoint(x: 0.234592 * w, y: 0.566453 * h),
            control2: CGPoint(x: 0.248318 * w, y: 0.563482 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.372872 * w, y: 0.630830 * h),
            control1: CGPoint(x: 0.298269 * w, y: 0.461719 * h),
            control2: CGPoint(x: 0.356874 * w, y: 0.479917 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.379590 * w, y: 0.637396 * h),
            control1: CGPoint(x: 0.373626 * w, y: 0.637969 * h),
            control2: CGPoint(x: 0.377069 * w, y: 0.641415 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.408626 * w, y: 0.661396 * h),
            control1: CGPoint(x: 0.390374 * w, y: 0.620219 * h),
            control2: CGPoint(x: 0.405015 * w, y: 0.627754 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.415415 * w, y: 0.668415 * h),
            control1: CGPoint(x: 0.409415 * w, y: 0.668755 * h),
            control2: CGPoint(x: 0.412828 * w, y: 0.672616 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.440085 * w, y: 0.670403 * h),
            control1: CGPoint(x: 0.422413 * w, y: 0.657082 * h),
            control2: CGPoint(x: 0.432097 * w, y: 0.655541 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.447338 * w, y: 0.663912 * h),
            control1: CGPoint(x: 0.442779 * w, y: 0.675421 * h),
            control2: CGPoint(x: 0.446708 * w, y: 0.672069 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.538597 * w, y: 0.548094 * h),
            control1: CGPoint(x: 0.455238 * w, y: 0.561894 * h),
            control2: CGPoint(x: 0.498597 * w, y: 0.499993 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.579105 * w, y: 0.529380 * h),
            control1: CGPoint(x: 0.552354 * w, y: 0.564638 * h),
            control2: CGPoint(x: 0.568941 * w, y: 0.557502 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.746990 * w, y: 0.558176 * h),
            control1: CGPoint(x: 0.628662 * w, y: 0.392250 * h),
            control2: CGPoint(x: 0.710418 * w, y: 0.421464 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.772900 * w, y: 0.567914 * h),
            control1: CGPoint(x: 0.752749 * w, y: 0.579693 * h),
            control2: CGPoint(x: 0.764746 * w, y: 0.584109 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.810962 * w, y: 0.552997 * h),
            control1: CGPoint(x: 0.782946 * w, y: 0.547961 * h),
            control2: CGPoint(x: 0.796903 * w, y: 0.538080 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.824518 * w, y: 0.537426 * h),
            control1: CGPoint(x: 0.816444 * w, y: 0.558815 * h),
            control2: CGPoint(x: 0.822651 * w, y: 0.551350 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.923918 * w, y: 0.500982 * h),
            control1: CGPoint(x: 0.838454 * w, y: 0.433425 * h),
            control2: CGPoint(x: 0.895533 * w, y: 0.403758 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.958346 * w, y: 0.545286 * h),
            control1: CGPoint(x: 0.931905 * w, y: 0.528342 * h),
            control2: CGPoint(x: 0.944631 * w, y: 0.544449 * h)
        )
        path.addCurve(
            to: CGPoint(x: 1.002562 * w, y: 0.581508 * h),
            control1: CGPoint(x: 0.976023 * w, y: 0.546357 * h),
            control2: CGPoint(x: 0.995000 * w, y: 0.559868 * h)
        )
        path.addLine(to: CGPoint(x: 1.002562 * w, y: 1.0 * h))
        path.addLine(to: CGPoint(x: 0.000000 * w, y: 1.0 * h))
        path.addLine(to: CGPoint(x: 0.000000 * w, y: 0.771006 * h))
        path.addCurve(
            to: CGPoint(x: 0.128779 * w, y: 0.633415 * h),
            control1: CGPoint(x: 0.013946 * w, y: 0.656981 * h),
            control2: CGPoint(x: 0.077388 * w, y: 0.593100 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.151549 * w, y: 0.610314 * h),
            control1: CGPoint(x: 0.137592 * w, y: 0.640327 * h),
            control2: CGPoint(x: 0.147294 * w, y: 0.630465 * h)
        )
        path.closeSubpath()

        return path
    }
}
