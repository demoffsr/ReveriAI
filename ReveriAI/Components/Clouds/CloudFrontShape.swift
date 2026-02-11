import SwiftUI

struct CloudFrontShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: 0.000000 * w, y: 0.499455 * h))
        path.addCurve(
            to: CGPoint(x: 0.171274 * w, y: 0.657069 * h),
            control1: CGPoint(x: 0.057238 * w, y: 0.429779 * h),
            control2: CGPoint(x: 0.143719 * w, y: 0.498058 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.201683 * w, y: 0.700673 * h),
            control1: CGPoint(x: 0.176373 * w, y: 0.686491 * h),
            control2: CGPoint(x: 0.188740 * w, y: 0.704434 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.296623 * w, y: 0.846767 * h),
            control1: CGPoint(x: 0.243103 * w, y: 0.688648 * h),
            control2: CGPoint(x: 0.281015 * w, y: 0.741220 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.329397 * w, y: 0.878925 * h),
            control1: CGPoint(x: 0.301433 * w, y: 0.879277 * h),
            control2: CGPoint(x: 0.316741 * w, y: 0.894170 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.422749 * w, y: 0.962610 * h),
            control1: CGPoint(x: 0.361085 * w, y: 0.840767 * h),
            control2: CGPoint(x: 0.401559 * w, y: 0.864792 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.435095 * w, y: 0.970969 * h),
            control1: CGPoint(x: 0.425126 * w, y: 0.973579 * h),
            control2: CGPoint(x: 0.430844 * w, y: 0.977730 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.467544 * w, y: 0.974736 * h),
            control1: CGPoint(x: 0.444310 * w, y: 0.956314 * h),
            control2: CGPoint(x: 0.457874 * w, y: 0.956396 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.480621 * w, y: 0.969208 * h),
            control1: CGPoint(x: 0.471782 * w, y: 0.982780 * h),
            control2: CGPoint(x: 0.477892 * w, y: 0.980522 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.513736 * w, y: 0.935384 * h),
            control1: CGPoint(x: 0.487182 * w, y: 0.941975 * h),
            control2: CGPoint(x: 0.500356 * w, y: 0.927541 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.524213 * w, y: 0.919541 * h),
            control1: CGPoint(x: 0.518392 * w, y: 0.938113 * h),
            control2: CGPoint(x: 0.523046 * w, y: 0.930925 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.700190 * w, y: 0.729484 * h),
            control1: CGPoint(x: 0.543069 * w, y: 0.735000 * h),
            control2: CGPoint(x: 0.623300 * w, y: 0.641811 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.711297 * w, y: 0.719943 * h),
            control1: CGPoint(x: 0.704323 * w, y: 0.734195 * h),
            control2: CGPoint(x: 0.709274 * w, y: 0.729956 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.759564 * w, y: 0.684038 * h),
            control1: CGPoint(x: 0.719818 * w, y: 0.677792 * h),
            control2: CGPoint(x: 0.741946 * w, y: 0.660881 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.771810 * w, y: 0.672698 * h),
            control1: CGPoint(x: 0.764254 * w, y: 0.690201 * h),
            control2: CGPoint(x: 0.770113 * w, y: 0.685082 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.835759 * w, y: 0.603318 * h),
            control1: CGPoint(x: 0.780287 * w, y: 0.610789 * h),
            control2: CGPoint(x: 0.808392 * w, y: 0.576411 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.868997 * w, y: 0.583306 * h),
            control1: CGPoint(x: 0.847356 * w, y: 0.614723 * h),
            control2: CGPoint(x: 0.860623 * w, y: 0.606058 * h)
        )
        path.addCurve(
            to: CGPoint(x: 1.002562 * w, y: 0.517952 * h),
            control1: CGPoint(x: 0.908879 * w, y: 0.474967 * h),
            control2: CGPoint(x: 0.970092 * w, y: 0.466896 * h)
        )
        path.addLine(to: CGPoint(x: 1.002562 * w, y: 1.0 * h))
        path.addLine(to: CGPoint(x: 0.000000 * w, y: 1.0 * h))
        path.addLine(to: CGPoint(x: 0.000000 * w, y: 0.499455 * h))
        path.closeSubpath()

        return path
    }
}
