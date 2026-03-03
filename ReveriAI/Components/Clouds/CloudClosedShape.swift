import SwiftUI

/// Inverted cloud shape — flat top, wavy cloud bumps on bottom.
/// Normalized from clouds_closed_new.svg (viewBox 390×140).
struct CloudClosedShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        // Start at right side, cloud edge
        path.move(to: CGPoint(x: 1.000000 * w, y: 0.475011 * h))
        path.addCurve(
            to: CGPoint(x: 0.866433 * w, y: 0.549347 * h),
            control1: CGPoint(x: 0.967528 * w, y: 0.416941 * h),
            control2: CGPoint(x: 0.906315 * w, y: 0.426123 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.833195 * w, y: 0.572221 * h),
            control1: CGPoint(x: 0.858062 * w, y: 0.575223 * h),
            control2: CGPoint(x: 0.844795 * w, y: 0.585079 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.769249 * w, y: 0.651018 * h),
            control1: CGPoint(x: 0.805828 * w, y: 0.541503 * h),
            control2: CGPoint(x: 0.777723 * w, y: 0.580603 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.757000 * w, y: 0.663914 * h),
            control1: CGPoint(x: 0.767551 * w, y: 0.665098 * h),
            control2: CGPoint(x: 0.761692 * w, y: 0.670928 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.708736 * w, y: 0.704759 * h),
            control1: CGPoint(x: 0.739385 * w, y: 0.637577 * h),
            control2: CGPoint(x: 0.717254 * w, y: 0.656814 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.697626 * w, y: 0.715607 * h),
            control1: CGPoint(x: 0.706710 * w, y: 0.716143 * h),
            control2: CGPoint(x: 0.701759 * w, y: 0.720964 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.521649 * w, y: 0.931779 * h),
            control1: CGPoint(x: 0.620736 * w, y: 0.616029 * h),
            control2: CGPoint(x: 0.540508 * w, y: 0.721879 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.511174 * w, y: 0.949793 * h),
            control1: CGPoint(x: 0.520485 * w, y: 0.944729 * h),
            control2: CGPoint(x: 0.515828 * w, y: 0.952900 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.478056 * w, y: 0.988264 * h),
            control1: CGPoint(x: 0.497795 * w, y: 0.940879 * h),
            control2: CGPoint(x: 0.484618 * w, y: 0.957300 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.464979 * w, y: 0.994557 * h),
            control1: CGPoint(x: 0.475331 * w, y: 1.001136 * h),
            control2: CGPoint(x: 0.469218 * w, y: 1.003700 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.432531 * w, y: 0.990279 * h),
            control1: CGPoint(x: 0.455310 * w, y: 0.973700 * h),
            control2: CGPoint(x: 0.441749 * w, y: 0.973607 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.420185 * w, y: 0.980757 * h),
            control1: CGPoint(x: 0.428279 * w, y: 0.997957 * h),
            control2: CGPoint(x: 0.422562 * w, y: 0.993236 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.326836 * w, y: 0.885579 * h),
            control1: CGPoint(x: 0.398995 * w, y: 0.869507 * h),
            control2: CGPoint(x: 0.358523 * w, y: 0.842186 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.294062 * w, y: 0.849000 * h),
            control1: CGPoint(x: 0.314179 * w, y: 0.902914 * h),
            control2: CGPoint(x: 0.298869 * w, y: 0.886121 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.199118 * w, y: 0.682839 * h),
            control1: CGPoint(x: 0.278451 * w, y: 0.728957 * h),
            control2: CGPoint(x: 0.240538 * w, y: 0.669161 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.168710 * w, y: 0.633246 * h),
            control1: CGPoint(x: 0.186176 * w, y: 0.687111 * h),
            control2: CGPoint(x: 0.173809 * w, y: 0.666707 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.000000 * w, y: 0.453971 * h),
            control1: CGPoint(x: 0.141156 * w, y: 0.452388 * h),
            control2: CGPoint(x: 0.057238 * w, y: 0.374721 * h)
        )
        // Flat top edge
        path.addLine(to: CGPoint(x: 0.000000 * w, y: 0.0 * h))
        path.addLine(to: CGPoint(x: 1.000000 * w, y: 0.0 * h))
        path.addLine(to: CGPoint(x: 1.000000 * w, y: 0.475011 * h))
        path.closeSubpath()

        return path
    }
}
