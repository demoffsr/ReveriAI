import SwiftUI

struct CloudFrontShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: 0.000000 * w, y: 0.106318 * h))
        path.addCurve(
            to: CGPoint(x: 0.168710 * w, y: 0.387899 * h),
            control1: CGPoint(x: 0.057238 * w, y: -0.018161 * h),
            control2: CGPoint(x: 0.141155 * w, y: 0.103822 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.199120 * w, y: 0.465800 * h),
            control1: CGPoint(x: 0.173809 * w, y: 0.440460 * h),
            control2: CGPoint(x: 0.186177 * w, y: 0.472512 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.294062 * w, y: 0.726794 * h),
            control1: CGPoint(x: 0.240540 * w, y: 0.444317 * h),
            control2: CGPoint(x: 0.278451 * w, y: 0.538236 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.326833 * w, y: 0.784248 * h),
            control1: CGPoint(x: 0.298869 * w, y: 0.784873 * h),
            control2: CGPoint(x: 0.314177 * w, y: 0.811478 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.420185 * w, y: 0.933751 * h),
            control1: CGPoint(x: 0.358521 * w, y: 0.716083 * h),
            control2: CGPoint(x: 0.398995 * w, y: 0.758997 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.432531 * w, y: 0.948689 * h),
            control1: CGPoint(x: 0.422562 * w, y: 0.953345 * h),
            control2: CGPoint(x: 0.428279 * w, y: 0.960761 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.464979 * w, y: 0.955419 * h),
            control1: CGPoint(x: 0.441749 * w, y: 0.922504 * h),
            control2: CGPoint(x: 0.455310 * w, y: 0.922654 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.478056 * w, y: 0.945534 * h),
            control1: CGPoint(x: 0.469218 * w, y: 0.969784 * h),
            control2: CGPoint(x: 0.475331 * w, y: 0.965752 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.511174 * w, y: 0.885109 * h),
            control1: CGPoint(x: 0.484618 * w, y: 0.896892 * h),
            control2: CGPoint(x: 0.497795 * w, y: 0.871103 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.521649 * w, y: 0.856808 * h),
            control1: CGPoint(x: 0.515831 * w, y: 0.889985 * h),
            control2: CGPoint(x: 0.520485 * w, y: 0.877148 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.697626 * w, y: 0.517271 * h),
            control1: CGPoint(x: 0.540508 * w, y: 0.527120 * h),
            control2: CGPoint(x: 0.620736 * w, y: 0.360634 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.708736 * w, y: 0.500225 * h),
            control1: CGPoint(x: 0.701759 * w, y: 0.525689 * h),
            control2: CGPoint(x: 0.706713 * w, y: 0.518115 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.757000 * w, y: 0.436075 * h),
            control1: CGPoint(x: 0.717254 * w, y: 0.424916 * h),
            control2: CGPoint(x: 0.739385 * w, y: 0.394708 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.769249 * w, y: 0.415822 * h),
            control1: CGPoint(x: 0.761692 * w, y: 0.447093 * h),
            control2: CGPoint(x: 0.767551 * w, y: 0.437937 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.833195 * w, y: 0.291871 * h),
            control1: CGPoint(x: 0.777723 * w, y: 0.305218 * h),
            control2: CGPoint(x: 0.805828 * w, y: 0.243800 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.866433 * w, y: 0.256119 * h),
            control1: CGPoint(x: 0.844795 * w, y: 0.312247 * h),
            control2: CGPoint(x: 0.858062 * w, y: 0.296765 * h)
        )
        path.addCurve(
            to: CGPoint(x: 1.000000 * w, y: 0.139364 * h),
            control1: CGPoint(x: 0.906315 * w, y: 0.062570 * h),
            control2: CGPoint(x: 0.967528 * w, y: 0.048151 * h)
        )
        path.addLine(to: CGPoint(x: 1.000000 * w, y: 1.0 * h))
        path.addLine(to: CGPoint(x: 0.000000 * w, y: 1.0 * h))
        path.addLine(to: CGPoint(x: 0.000000 * w, y: 0.106318 * h))
        path.closeSubpath()

        return path
    }
}
