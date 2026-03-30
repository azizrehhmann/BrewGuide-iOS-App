import SwiftUI

struct BeanConfirmView: View {
    @ObservedObject var viewModel: BeanFirstViewModel
    @State var beanProfile: BeanProfile
    @Environment(\.colorScheme) private var colorScheme

    private let roastLevels = ["Light", "Medium-Light", "Medium", "Medium-Dark", "Dark"]
    private let processes = ["Washed", "Natural", "Honey", "Anaerobic", "Other"]

    @State private var newFlavourNote = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 4) {
                    Text("Confirm Bean Details")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(Constants.Colors.primaryColor)

                    Text("Edit any fields the scanner may have missed")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 8)

                // Fields
                VStack(spacing: 16) {
                    fieldRow(label: "Name", text: $beanProfile.name, placeholder: "e.g. Ethiopian Yirgacheffe")
                    fieldRow(label: "Roaster", text: binding(for: \.roaster), placeholder: "e.g. Square Mile")
                    fieldRow(label: "Origin", text: binding(for: \.origin), placeholder: "e.g. Ethiopia")
                    fieldRow(label: "Region", text: binding(for: \.region), placeholder: "e.g. Yirgacheffe")
                    fieldRow(label: "Variety", text: binding(for: \.variety), placeholder: "e.g. Heirloom")
                    fieldRow(label: "Altitude", text: binding(for: \.altitude), placeholder: "e.g. 1800-2200m")

                    // Roast level picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Roast Level")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(roastLevels, id: \.self) { level in
                                    Button {
                                        beanProfile.roastLevel = level
                                        HapticsManager.shared.selection()
                                    } label: {
                                        Text(level)
                                            .font(.system(.caption, design: .rounded, weight: .medium))
                                            .foregroundStyle(
                                                beanProfile.roastLevel == level ? .white : Constants.Colors.primaryColor.opacity(0.7)
                                            )
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(
                                                Capsule().fill(
                                                    beanProfile.roastLevel == level
                                                    ? Constants.Colors.accentGold
                                                    : Constants.Colors.cardBackground
                                                )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Process picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Process")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(processes, id: \.self) { proc in
                                    Button {
                                        beanProfile.process = proc
                                        HapticsManager.shared.selection()
                                    } label: {
                                        Text(proc)
                                            .font(.system(.caption, design: .rounded, weight: .medium))
                                            .foregroundStyle(
                                                beanProfile.process == proc ? .white : Constants.Colors.primaryColor.opacity(0.7)
                                            )
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(
                                                Capsule().fill(
                                                    beanProfile.process == proc
                                                    ? Constants.Colors.accentGold
                                                    : Constants.Colors.cardBackground
                                                )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Flavour notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Flavour Notes")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)

                        FlowLayout(spacing: 6) {
                            ForEach(beanProfile.flavourNotes, id: \.self) { note in
                                HStack(spacing: 4) {
                                    Text(note)
                                    Button {
                                        beanProfile.flavourNotes.removeAll { $0 == note }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 8, weight: .bold))
                                    }
                                }
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .foregroundStyle(Constants.Colors.primaryColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Constants.Colors.accentGold.opacity(0.08)))
                            }
                        }

                        HStack(spacing: 8) {
                            TextField("Add note...", text: $newFlavourNote)
                                .font(.system(.caption, design: .rounded))
                                .textFieldStyle(.plain)

                            Button {
                                let trimmed = newFlavourNote.trimmingCharacters(in: .whitespaces)
                                guard !trimmed.isEmpty else { return }
                                beanProfile.flavourNotes.append(trimmed)
                                newFlavourNote = ""
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Constants.Colors.accentGold)
                            }
                            .disabled(newFlavourNote.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: Constants.Layout.smallCornerRadius, style: .continuous)
                                .fill(Constants.Colors.cardBackground)
                        )
                    }
                }
                .padding(.horizontal, Constants.Layout.horizontalPadding)

                // Confirm button
                Button {
                    viewModel.confirmBean(beanProfile)
                    HapticsManager.shared.impact(style: .medium)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Get Recommendations")
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                            .fill(beanProfile.name.isEmpty
                                  ? Constants.Colors.accentGold.opacity(0.4)
                                  : Constants.Colors.accentGold)
                    )
                }
                .disabled(beanProfile.name.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, Constants.Layout.horizontalPadding)
                .padding(.top, 8)
            }
            .padding(.vertical)
        }
        .adaptiveBackground()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Constants.Colors.primaryColor)
                }
            }
        }
    }

    // MARK: - Helpers

    private func fieldRow(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: Constants.Layout.smallCornerRadius, style: .continuous)
                        .fill(Constants.Colors.cardBackground)
                )
        }
    }

    /// Create a binding for an optional String property
    private func binding(for keyPath: WritableKeyPath<BeanProfile, String?>) -> Binding<String> {
        Binding(
            get: { beanProfile[keyPath: keyPath] ?? "" },
            set: { newValue in
                beanProfile[keyPath: keyPath] = newValue.isEmpty ? nil : newValue
            }
        )
    }
}
