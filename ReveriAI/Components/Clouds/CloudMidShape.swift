import SwiftUI

struct CloudMidShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: 0.148985 * w, y: 0.304370 * h))
        path.addCurve(
            to: CGPoint(x: 0.220841 * w, y: 0.200346 * h),
            control1: CGPoint(x: 0.161702 * w, y: 0.196797 * h),
            control2: CGPoint(x: 0.192787 * w, y: 0.135994 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.255468 * w, y: 0.185356 * h),
            control1: CGPoint(x: 0.232028 * w, y: 0.226012 * h),
            control2: CGPoint(x: 0.245755 * w, y: 0.220704 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.370308 * w, y: 0.341027 * h),
            control1: CGPoint(x: 0.295708 * w, y: 0.038903 * h),
            control2: CGPoint(x: 0.354310 * w, y: 0.071413 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.377026 * w, y: 0.352757 * h),
            control1: CGPoint(x: 0.371064 * w, y: 0.353776 * h),
            control2: CGPoint(x: 0.374505 * w, y: 0.359936 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.406064 * w, y: 0.395626 * h),
            control1: CGPoint(x: 0.387810 * w, y: 0.322066 * h),
            control2: CGPoint(x: 0.402451 * w, y: 0.335527 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.412851 * w, y: 0.408173 * h),
            control1: CGPoint(x: 0.406854 * w, y: 0.408771 * h),
            control2: CGPoint(x: 0.410264 * w, y: 0.415669 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.437521 * w, y: 0.411724 * h),
            control1: CGPoint(x: 0.419851 * w, y: 0.387920 * h),
            control2: CGPoint(x: 0.429533 * w, y: 0.385171 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.444774 * w, y: 0.400125 * h),
            control1: CGPoint(x: 0.440215 * w, y: 0.420685 * h),
            control2: CGPoint(x: 0.444144 * w, y: 0.414693 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.536033 * w, y: 0.193212 * h),
            control1: CGPoint(x: 0.452674 * w, y: 0.217867 * h),
            control2: CGPoint(x: 0.496036 * w, y: 0.107280 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.576541 * w, y: 0.159780 * h),
            control1: CGPoint(x: 0.549790 * w, y: 0.222770 * h),
            control2: CGPoint(x: 0.566377 * w, y: 0.210020 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.744428 * w, y: 0.211224 * h),
            control1: CGPoint(x: 0.626100 * w, y: -0.085206 * h),
            control2: CGPoint(x: 0.707854 * w, y: -0.033014 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.770338 * w, y: 0.228621 * h),
            control1: CGPoint(x: 0.750185 * w, y: 0.249665 * h),
            control2: CGPoint(x: 0.762185 * w, y: 0.257555 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.808397 * w, y: 0.201972 * h),
            control1: CGPoint(x: 0.780385 * w, y: 0.192974 * h),
            control2: CGPoint(x: 0.794341 * w, y: 0.175322 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.821954 * w, y: 0.174154 * h),
            control1: CGPoint(x: 0.813882 * w, y: 0.212366 * h),
            control2: CGPoint(x: 0.820087 * w, y: 0.199028 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.921354 * w, y: 0.109046 * h),
            control1: CGPoint(x: 0.835892 * w, y: -0.011645 * h),
            control2: CGPoint(x: 0.892972 * w, y: -0.064646 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.955785 * w, y: 0.188194 * h),
            control1: CGPoint(x: 0.929344 * w, y: 0.157925 * h),
            control2: CGPoint(x: 0.942069 * w, y: 0.186701 * h)
        )
        path.addCurve(
            to: CGPoint(x: 1.000000 * w, y: 0.252908 * h),
            control1: CGPoint(x: 0.973459 * w, y: 0.190110 * h),
            control2: CGPoint(x: 0.992438 * w, y: 0.214247 * h)
        )
        path.addLine(to: CGPoint(x: 1.000000 * w, y: 1.0 * h))
        path.addLine(to: CGPoint(x: 0.000000 * w, y: 1.0 * h))
        path.addLine(to: CGPoint(x: 0.000000 * w, y: 0.591452 * h))
        path.addCurve(
            to: CGPoint(x: 0.126215 * w, y: 0.345640 * h),
            control1: CGPoint(x: 0.013946 * w, y: 0.387745 * h),
            control2: CGPoint(x: 0.074824 * w, y: 0.273617 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.148985 * w, y: 0.304370 * h),
            control1: CGPoint(x: 0.135028 * w, y: 0.357993 * h),
            control2: CGPoint(x: 0.144731 * w, y: 0.340369 * h)
        )
        path.closeSubpath()

        return path
    }
}
