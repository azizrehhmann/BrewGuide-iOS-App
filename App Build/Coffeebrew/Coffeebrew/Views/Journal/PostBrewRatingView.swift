import SwiftUI

struct PostBrewRatingView: View {
    let session: BrewSession
    @ObservedObject var journalViewModel: BrewJournalViewModel
    @Binding var isPresented: Bool

    @State private var selectedRating: Int = 0
    @State private var selectedTags: Set<String> = []
    @State private var quickNote: String = ""
    @FocusState private var noteFieldFocused: Bool

    private let suggestedTags = [
        "Fruity", "Floral", "Bright", "Sweet", "Chocolatey",
        "Nutty", "Earthy", "Smoky", "Bitter", "Balanced",
        "Acidic", "Smooth", "Bold", "Mild", "Complex"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    Divider()
                    ratingSection
                    flavourTagsSection
                    quickNoteSection
                    actionButtons
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .foregroundStyle(Constants.Colors.accentGold)
                }
            }
            .onTapGesture { noteFieldFocused = false }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 6) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 40))
                .foregroundStyle(Constants.Colors.accentGold)
            Text("Brew Complete")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Constants.Colors.primaryColor)
            Text(session.techniqueName ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var ratingSection: some View {
        VStack(spacing: 12) {
            Text("How was it?")
                .font(.headline)
                .foregroundStyle(Constants.Colors.primaryColor)
            RatingStarsView(
                rating: selectedRating,
                size: 36,
                interactive: true,
                onRatingChanged: { selectedRating = $0 }
            )
            if selectedRating > 0 {
                Text(ratingLabel(selectedRating))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.spring(response: 0.3), value: selectedRating)
    }

    private var flavourTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flavour notes")
                .font(.headline)
                .foregroundStyle(Constants.Colors.primaryColor)
            FlowLayout(spacing: 8) {
                ForEach(suggestedTags, id: \.self) { tag in
                    TagPill(
                        label: tag,
                        isSelected: selectedTags.contains(tag),
                        onTap: { toggleTag(tag) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quickNoteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick note (optional)")
                .font(.headline)
                .foregroundStyle(Constants.Colors.primaryColor)
            TextField("Any observations...", text: $quickNote, axis: .vertical)
                .lineLimit(3...5)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .focused($noteFieldFocused)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                saveAndDismiss()
            } label: {
                Text("Save to Journal")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Constants.Colors.accentGold, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }

            Button("Skip") { isPresented = false }
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    private func saveAndDismiss() {
        if selectedRating > 0 {
            journalViewModel.updateRating(selectedRating, for: session)
        }
        if !selectedTags.isEmpty {
            journalViewModel.updateFlavourTags(Array(selectedTags), for: session)
        }
        if !quickNote.isEmpty {
            journalViewModel.updateNotes(quickNote, for: session)
        }
        isPresented = false
    }

    private func ratingLabel(_ rating: Int) -> String {
        ["", "Not great", "It was okay", "Pretty good", "Really good", "Perfect"][rating]
    }
}
