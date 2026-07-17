import SwiftUI

/// A reusable full-space view for loading, empty, and error states so
/// each screen doesn't have to re-implement the same layout.
struct StatusView: View {
    enum Kind {
        case loading
        case empty(title: String, message: String, systemImage: String)
        case error(message: String, retry: (() -> Void)?)
    }

    let kind: Kind

    var body: some View {
        switch kind {
        case .loading:
            ProgressView("Loading")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty(let title, let message, let systemImage):
            ContentUnavailableStyleView(
                systemImage: systemImage,
                title: title,
                message: message
            )

        case .error(let message, let retry):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                Text("Something went wrong")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                if let retry {
                    Button("Try Again", action: retry)
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// A manual stand in for `ContentUnavailableView` styling so this file
/// works even on the minimum supported iOS 17 deployment target.
private struct ContentUnavailableStyleView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
