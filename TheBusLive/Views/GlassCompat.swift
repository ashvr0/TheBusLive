import SwiftUI

/// Cross-version glass background. Uses iOS 26 Liquid Glass (`.glassEffect`)
/// when available, falls back to `.regularMaterial` on iOS 17-25.
extension View {
    @ViewBuilder
    func glassBackground<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                tint.map { Glass.regular.tint($0) } ?? .regular,
                in: shape
            )
        } else {
            self
                .background(.regularMaterial, in: shape)
                .shadow(radius: 4)
        }
    }
}

/// Groups multiple glass elements so they morph/merge together on iOS 26.
/// No-op wrapper pre-26.
struct GlassGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer {
                content
            }
        } else {
            content
        }
    }
}

/// Applies the real `.glass` button style on iOS 26, `.plain` before that.
struct GlassButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.plain)
        }
    }
}
