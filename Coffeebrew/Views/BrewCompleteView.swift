import SwiftUI

struct BrewCompleteView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    let session: BrewSession
    @ObservedObject var journal: BrewJournalViewModel

    @State private var rating: Int = 0
    @State private var showDiscardConfirm = false
    @State private var note: String = ""
    @State private var selectedNotes: Set<String> = []
    @State private var showContent = false

    private let tastingNotes = ["Floral", "Citrus", "Stone fruit", "Berry", "Chocolate", "Nutty", "Caramel", "Clean", "Bright", "Earthy"]
    private let ratingLabels = ["Meh", "Fine", "Good", "Great", "Perfect"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // MARK: - Eyebrow + Heading
                VStack(alignment: .leading, spacing: 12) {
                    KEyebrow(text: "BREW COMPLETE", showDot: true)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 12)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("How was it,")
                            .font(Constants.Typography.display(40))
                            .foregroundStyle(Constants.Colors.primaryColor)
                        Text("this cup?")
                            .font(Constants.Typography.displayItalic(40))
                            .foregroundStyle(Constants.Colors.accentGold)
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 12)
                }
                .padding(.top, 16)

                // MARK: - Star Rating Card
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    rating = star
                                }
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.system(size: 32))
                                    .foregroundStyle(star <= rating ? Constants.Colors.accentGold : Constants.Colors.primaryColor.opacity(0.2))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                        }
                    }

                    Text(rating > 0 ? ratingLabels[rating - 1] : "Tap a star")
                        .font(Constants.Typography.mono(11))
                        .foregroundStyle(Constants.Colors.primaryColor.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .elevatedCardStyle()
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 16)

                // MARK: - Tasting Notes
                VStack(alignment: .leading, spacing: 12) {
                    KEyebrow(text: "TASTING NOTES")

                    FlowLayout(spacing: 8) {
                        ForEach(tastingNotes, id: \.self) { note in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedNotes.contains(note) {
                                        selectedNotes.remove(note)
                                    } else {
                                        selectedNotes.insert(note)
                                    }
                                }
                            } label: {
                                Text(note)
                                    .font(Constants.Typography.sans(12))
                                    .foregroundStyle(selectedNotes.contains(note) ? .white : Constants.Colors.primaryColor)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(
                                        Capsule()
                                            .fill(selectedNotes.contains(note) ? Constants.Colors.accentGold : Constants.Colors.cardBackground)
                                    )
                                    .overlay(
                                        selectedNotes.contains(note)
                                            ? nil
                                            : Capsule()
                                                .strokeBorder(Constants.Colors.primaryColor.opacity(0.12), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 16)

                // MARK: - Note to Self
                VStack(alignment: .leading, spacing: 12) {
                    KEyebrow(text: "NOTE TO SELF")

                    ZStack(alignment: .topLeading) {
                        if note.isEmpty {
                            Text("How did it taste?")
                                .font(Constants.Typography.displayItalic(15))
                                .foregroundStyle(Constants.Colors.primaryColor.opacity(0.3))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                        }
                        TextEditor(text: $note)
                            .font(Constants.Typography.sans(14))
                            .foregroundStyle(Constants.Colors.primaryColor)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .frame(minHeight: 96)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Constants.Colors.cardBackground)
                    )
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 16)

                // MARK: - Buttons
                HStack(spacing: 12) {
                    KButton(title: "Discard", variant: .ghost, fullWidth: false) {
                        showDiscardConfirm = true
                    }

                    KButton(title: "Save to journal", icon: "checkmark", variant: .primary) {
                        saveAndFinish()
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 16)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .adaptiveBackground()
        .navigationBarBackButtonHidden(true)
        .confirmationDialog("Remove this brew from your journal?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
            Button("Discard brew", role: .destructive) {
                journal.delete(session)
                appEnvironment.reset()
            }
        }
        .onAppear {
            if reduceMotion {
                showContent = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15)) {
                    showContent = true
                }
            }
        }
    }

    private func saveAndFinish() {
        if rating > 0 { journal.updateRating(rating, for: session) }
        if !selectedNotes.isEmpty { journal.updateFlavourTags(selectedNotes.sorted(), for: session) }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { journal.updateNotes(trimmed, for: session) }
        appEnvironment.reset()
    }
}
