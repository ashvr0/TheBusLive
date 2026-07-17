import SwiftUI

/// A text view that automatically scrolls left-to-right-and-back when its
/// content doesn't fit the available width, similar to a ticker. Falls
/// back to plain (non-scrolling) text when it already fits, so short
/// labels don't animate unnecessarily.
struct MarqueeText: View {
    let text: String
    var font: Font = .body
    var fontWeight: Font.Weight? = nil

    @State private var containerWidth: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var animate = false

    private var needsScrolling: Bool {
        textWidth > containerWidth && containerWidth > 0
    }

    /// How far the text needs to travel, plus a little breathing room.
    private var scrollDistance: CGFloat {
        max(textWidth - containerWidth, 0)
    }

    var body: some View {
        GeometryReader { geo in
            singleLineText
                .fixedSize()
                .background(
                    GeometryReader { textGeo in
                        Color.clear
                            .onAppear {
                                textWidth = textGeo.size.width
                                containerWidth = geo.size.width
                            }
                            .onChange(of: textGeo.size.width) { _, newValue in
                                textWidth = newValue
                            }
                    }
                )
                .offset(x: needsScrolling ? (animate ? -scrollDistance : 0) : 0)
                .onAppear {
                    containerWidth = geo.size.width
                    startAnimationIfNeeded()
                }
                .onChange(of: geo.size.width) { _, newValue in
                    containerWidth = newValue
                    startAnimationIfNeeded()
                }
                .onChange(of: textWidth) { _, _ in
                    startAnimationIfNeeded()
                }
                .frame(width: geo.size.width, alignment: .leading)
                .clipped()
        }
        .frame(height: singleLineHeight)
    }

    private var singleLineText: Text {
        Text(text)
            .font(font)
            .fontWeight(fontWeight)
    }

    /// A reasonable fixed height so the GeometryReader-based layout
    /// doesn't collapse to zero height before content loads.
    private var singleLineHeight: CGFloat {
        switch font {
        case .caption, .caption2: return 16
        case .footnote: return 18
        case .subheadline: return 20
        case .headline, .body: return 22
        case .title3: return 26
        default: return 22
        }
    }

    private func startAnimationIfNeeded() {
        guard needsScrolling else {
            animate = false
            return
        }
        // Reset then kick off a repeating scroll-out/scroll-back cycle
        // with pauses at each end, rather than a single one-shot slide.
        animate = false
        let travelDuration = Double(scrollDistance) / 40.0 // ~40pt/sec
        let cycle = travelDuration + 1.2 // pause at the far edge

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(
                Animation.easeInOut(duration: travelDuration)
                    .delay(0.6)
                    .repeatForever(autoreverses: true)
            ) {
                animate = true
            }
            _ = cycle // duration used for pacing reference above
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
