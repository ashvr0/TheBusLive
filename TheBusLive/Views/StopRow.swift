import SwiftUI

/// A reusable row representing a stop, used in search results, favorites,
/// and the recents list. For favorites, displays and allows editing of notes.
struct StopRow: View {
    let stop: Stop
    var isFavorite: Bool = false
    var favoriteNote: String = ""
    var onToggleFavorite: (() -> Void)? = nil
    var onUpdateNote: ((String) -> Void)? = nil
    var isEditingNote: Bool = false

    @State private var editingNote: String = ""
    @State private var showNoteEditor = false

    private var hasExpressRoute: Bool {
        stop.routeShortNames.contains { RouteCategory.isExpress(routeNum: $0) }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "signpost.right.fill")
                .foregroundStyle(hasExpressRoute ? BusRoute.expressColor : Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(text: stop.name, font: .subheadline, fontWeight: .medium)

                HStack(spacing: 4) {
                    Text("Stop \(stop.stopID)" + (stop.routeShortNames.isEmpty ? "" : " · Routes \(stop.routeShortNames.joined(separator: ", "))"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if hasExpressRoute {
                        ExpressBadge()
                    }
                }

                if isFavorite && !favoriteNote.isEmpty {
                    Text(favoriteNote)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let onToggleFavorite {
                HStack(spacing: 8) {
                    if isFavorite && onUpdateNote != nil {
                        Button {
                            editingNote = favoriteNote
                            showNoteEditor = true
                        } label: {
                            Image(systemName: "note.text")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundStyle(isFavorite ? .yellow : .secondary)
                            .symbolEffect(.bounce, value: isFavorite)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isFavorite)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 2)
        .sheet(isPresented: $showNoteEditor) {
            NoteEditorSheet(
                stopName: stop.name,
                note: $editingNote,
                onSave: {
                    onUpdateNote?(editingNote)
                    showNoteEditor = false
                },
                onCancel: {
                    showNoteEditor = false
                }
            )
        }
    }
}

/// Modal sheet for editing a stop's favorite note.
struct NoteEditorSheet: View {
    let stopName: String
    @Binding var note: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stop")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text(stopName)
                        .font(.body)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Add a label")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    TextField("e.g., home -> work", text: $note)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()

                    Text("Use a short label to help you remember which bus to take from this stop")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(role: .cancel) {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onSave()
                    } label: {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    List {
        StopRow(
            stop: Stop.sampleStops[0],
            isFavorite: true,
            favoriteNote: "Home to work",
            onToggleFavorite: {},
            onUpdateNote: { _ in }
        )
        StopRow(
            stop: Stop.sampleStops[1],
            isFavorite: false,
            onToggleFavorite: {}
        )
    }
}