import SwiftUI
import CoreData

struct BrewJournalView: View {
    @StateObject private var viewModel: BrewJournalViewModel

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: BrewJournalViewModel(context: context))
    }

    var body: some View {
        Group {
            if viewModel.sessions.isEmpty && viewModel.searchText.isEmpty
                && viewModel.filterRating == 0 && !viewModel.filterFavourites {
                emptyState
            } else {
                sessionList
            }
        }
        .navigationTitle("Brew Journal")
        .toolbar { toolbarContent }
        .searchable(text: $viewModel.searchText, prompt: "Search techniques, beans...")
        .onChange(of: viewModel.searchText) { _, _ in viewModel.fetchSessions() }
        .onChange(of: viewModel.filterRating) { _, _ in viewModel.fetchSessions() }
        .onChange(of: viewModel.filterFavourites) { _, _ in viewModel.fetchSessions() }
        .onChange(of: viewModel.sortOrder) { _, _ in viewModel.fetchSessions() }
    }

    // MARK: - Session List

    private var sessionList: some View {
        List {
            // Stats header
            Section {
                statsHeader
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            // Filter chips
            Section {
                filterChips
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

            // Sessions
            Section {
                ForEach(viewModel.sessions, id: \.objectID) { session in
                    NavigationLink {
                        BrewSessionDetailView(
                            session: session,
                            journalViewModel: viewModel
                        )
                    } label: {
                        BrewSessionRowView(session: session)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel.delete(session)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            viewModel.toggleFavourite(session)
                        } label: {
                            Label(
                                session.isFavourite ? "Unfavourite" : "Favourite",
                                systemImage: session.isFavourite ? "heart.slash" : "heart"
                            )
                        }
                        .tint(.pink)
                    }
                }
            } header: {
                Text("\(viewModel.sessions.count) brew\(viewModel.sessions.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 0) {
            statCell(
                value: "\(viewModel.totalBrews)",
                label: "Total brews"
            )
            Divider().frame(height: 36)
            statCell(
                value: viewModel.averageRating > 0
                    ? String(format: "%.1f", viewModel.averageRating)
                    : "\u{2014}",
                label: "Avg rating"
            )
            Divider().frame(height: 36)
            statCell(
                value: viewModel.mostBrewedMethod ?? "\u{2014}",
                label: "Top method"
            )
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Constants.Colors.primaryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: "Favourites",
                    systemImage: "heart.fill",
                    isActive: viewModel.filterFavourites
                ) {
                    viewModel.filterFavourites.toggle()
                }
                ForEach(1...5, id: \.self) { stars in
                    FilterChip(
                        label: "\(stars)\u{2605}+",
                        isActive: viewModel.filterRating == stars
                    ) {
                        viewModel.filterRating = viewModel.filterRating == stars ? 0 : stars
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 52))
                .foregroundStyle(Constants.Colors.accentGold.opacity(0.5))
            Text("No brews yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Constants.Colors.primaryColor)
            Text("Complete a brew to start your journal.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort", selection: $viewModel.sortOrder) {
                    ForEach(BrewJournalViewModel.SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundStyle(Constants.Colors.primaryColor)
            }
        }
    }
}
