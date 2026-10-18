import SwiftUI

struct BrewSessionDetailView: View {
    let session: BrewSession
    @ObservedObject var journalViewModel: BrewJournalViewModel

    @State private var editingNotes = false
    @State private var notesText: String = ""
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                ratingSection
                parametersSection

                if let tags = session.flavourTags, !tags.isEmpty {
                    flavourTagsSection(tags)
                }

                notesSection
                actionButtons
            }
            .padding(16)
        }
        .adaptiveBackground()
        .navigationTitle(session.brewedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    journalViewModel.toggleFavourite(session)
                } label: {
                    Image(systemName: session.isFavourite ? "heart.fill" : "heart")
                        .foregroundStyle(session.isFavourite ? .pink : Constants.Colors.primaryColor)
                }
            }
        }
        .confirmationDialog("Delete this brew?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                journalViewModel.delete(session)
                dismiss()
            }
        }
        .onAppear { notesText = session.notes ?? "" }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 6) {
            Text(session.techniqueName ?? "")
                .font(Constants.Typography.display(24))
                .foregroundStyle(Constants.Colors.primaryColor)
                .multilineTextAlignment(.center)
            Text(session.equipmentName ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let bean = session.beanName, !bean.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.caption)
                    Text(bean)
                        .font(.caption)
                }
                .foregroundStyle(Constants.Colors.accentGold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Rating

    private var ratingSection: some View {
        VStack(spacing: 12) {
            KEyebrow(text: "RATING")
                .frame(maxWidth: .infinity, alignment: .leading)
            KRatingStars(
                rating: Double(session.rating),
                interactive: true,
                onRate: { journalViewModel.updateRating($0, for: session) },
                starSize: 32
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Parameters

    private var parametersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parameters")
                .font(.headline)
                .foregroundStyle(Constants.Colors.primaryColor)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                paramCell(label: "Coffee", value: String(format: "%.0fg", session.coffeeAmountGrams))
                paramCell(label: "Water", value: String(format: "%.0fml", session.waterAmountMl))
                paramCell(label: "Grind", value: session.grindSize ?? "\u{2014}")
                paramCell(label: "Temp", value: String(format: "%.0f\u{00B0}C", session.waterTempC))
                paramCell(label: "Servings", value: "\(session.servingSize) cup\(session.servingSize == 1 ? "" : "s")")
                paramCell(label: "Brew time", value: formatTime(Int(session.totalBrewTimeSeconds)))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func paramCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Constants.Colors.accentGold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Flavour Tags

    private func flavourTagsSection(_ tagsString: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flavour notes")
                .font(.headline)
                .foregroundStyle(Constants.Colors.primaryColor)
            FlowLayout(spacing: 8) {
                ForEach(tagsString.components(separatedBy: ","), id: \.self) { tag in
                    Text(tag.trimmingCharacters(in: .whitespaces))
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Constants.Colors.accentGold.opacity(0.15), in: Capsule())
                        .foregroundStyle(Constants.Colors.accentGold)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.headline)
                    .foregroundStyle(Constants.Colors.primaryColor)
                Spacer()
                Button(editingNotes ? "Done" : "Edit") {
                    if editingNotes {
                        journalViewModel.updateNotes(notesText, for: session)
                    }
                    editingNotes.toggle()
                }
                .font(.subheadline)
                .foregroundStyle(Constants.Colors.accentGold)
            }
            if editingNotes {
                TextField("Add tasting notes...", text: $notesText, axis: .vertical)
                    .lineLimit(4...8)
                    .padding(12)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            } else {
                let hasNotes = session.notes?.isEmpty == false
                Text(hasNotes ? session.notes! : "No notes added yet.")
                    .font(.body)
                    .foregroundStyle(hasNotes ? .primary : .secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete brew", systemImage: "trash")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m)m" : "\(m)m \(s)s"
    }
}
