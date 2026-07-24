import SwiftUI

/// A text view that automatically scrolls left-to-right-and-back when its
/// content doesn't fit the available width, similar to a ticker. Falls
/// back to plain (non-scrolling) text when it already fits, so short
/// labels don't animate unnecessarily.
///
/// Uses `.onGeometryChange` rather than nested `GeometryReader`s: this
/// view is instantiated per-row in Search/Favorites/Recents lists, and
/// `GeometryReader` forces an extra layout pass on every containing view.
/// `.onGeometryChange` reads geometry without that cost. Height is
/// measured from the rendered text rather than hardcoded, so the view
/// scales correctly at every Dynamic Type size.
struct MarqueeText: View {
    let text: String
    var font: Font = .body
    var fontWeight: Font.Weight? = nil

    @State private var containerWidth: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var textHeight: CGFloat = 22
    @State private var animate = false
    @State private var animationTask: Task<Void, Never>?

    private var needsScrolling: Bool {
        textWidth > containerWidth && containerWidth > 0
    }

    /// How far the text needs to travel, plus a little breathing room.
    private var scrollDistance: CGFloat {
        max(textWidth - containerWidth, 0)
    }

    var body: some View {
        singleLineText
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newValue in
                textWidth = newValue.width
                textHeight = newValue.height
                startAnimationIfNeeded()
            }
            .offset(x: needsScrolling ? (animate ? -scrollDistance : 0) : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newValue in
                containerWidth = newValue
                startAnimationIfNeeded()
            }
            .clipped()
            .frame(height: textHeight)
            .onDisappear {
                animationTask?.cancel()
                animationTask = nil
            }
    }

    private var singleLineText: Text {
        Text(text)
            .font(font)
            .fontWeight(fontWeight)
    }

    /// Starts (or restarts) the repeating scroll-out/scroll-back cycle.
    /// Cancels any in-flight scheduling first, so the redundant calls from
    /// the two `.onGeometryChange` sites collapse into a single active
    /// timer rather than stacking work.
    private func startAnimationIfNeeded() {
        animationTask?.cancel()

        guard needsScrolling else {
            animate = false
            animationTask = nil
            return
        }

        animate = false
        let travelDuration = Double(scrollDistance) / 40.0 // ~40pt/sec

        animationTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000) // pause before first scroll
            guard !Task.isCancelled else { return }

            withAnimation(
                Animation.easeInOut(duration: travelDuration)
                    .repeatForever(autoreverses: true)
            ) {
                animate = true
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        MarqueeText(text: "Short", font: .headline)
            .frame(width: 200)

        MarqueeText(text: "S KING ST + PENSACOLA ST", font: .headline)
            .frame(width: 160)

        MarqueeText(text: "Waikiki - Kahala Mall via Diamond Head", font: .subheadline)
            .frame(width: 220)
    }
    .padding()
}