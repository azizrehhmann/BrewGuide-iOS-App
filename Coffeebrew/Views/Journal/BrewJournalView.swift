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
                sessionContent
            }
        }
        .toolbar { toolbarContent }
        // Top drawer: the default bottom search would stack under the floating tab bar
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search techniques, beans...")
        .navigationTitle(viewModel.sessions.isEmpty ? "Journal" : "")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.searchText) { _, _ in viewModel.fetchSessions() }
        .onChange(of: viewModel.filterRating) { _, _ in viewModel.fetchSessions() }
        .onChange(of: viewModel.filterFavourites) { _, _ in viewModel.fetchSessions() }
        .onChange(of: viewModel.sortOrder) { _, _ in viewModel.fetchSessions() }
    }

    // MARK: - Session Content

    private var sessionContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Custom header
                customHeader

                // Streak card
                streakCard

                // Filter chips
                filterChips

                // Entry count
                KEyebrow(
                    text: "\(viewModel.sessions.count) BREW\(viewModel.sessions.count == 1 ? "" : "S")",
                    color: Constants.Colors.primaryColor.opacity(0.5)
                )

                // Session entries
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.sessions, id: \.objectID) { session in
                        NavigationLink {
                            BrewSessionDetailView(
                                session: session,
                                journalViewModel: viewModel
                            )
                        } label: {
                            entryCard(for: session)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
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
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .adaptiveBackground()
    }

    // MARK: - Custom Header

    private var customHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            KEyebrow(text: "\(viewModel.totalBrews) ENTRIES")

            Text("Journal")
                .font(Constants.Typography.display(40))
                .foregroundStyle(Constants.Colors.primaryColor)
        }
        .padding(.top, 8)
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        HStack {
            // Left side: brew count this week
            VStack(alignment: .leading, spacing: 4) {
                KEyebrow(text: "THIS WEEK")

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(brewsThisWeek)")
                        .font(Constants.Typography.display(28))
                        .foregroundStyle(Constants.Colors.primaryColor)
                    Text("brews")
                        .font(Constants.Typography.displayItalic(18))
                        .foregroundStyle(Constants.Colors.primaryColor.opacity(0.5))
                }
            }

            Spacer()

            // Right side: 7 day-of-week dots
            HStack(spacing: 6) {
                ForEach(weekDays, id: \.label) { day in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(day.brewed ? Constants.Colors.accentGold : Constants.Colors.primaryColor.opacity(0.06))
                                .frame(width: 22, height: 22)
                            if day.brewed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        Text(day.label)
                            .font(Constants.Typography.mono(9))
                            .foregroundStyle(Constants.Colors.primaryColor.opacity(0.5))
                    }
                }
            }
        }
        .padding(20)
        .elevatedCardStyle()
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

    // MARK: - Entry Card

    private func entryCard(for session: BrewSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: date + rating
            HStack {
                KEyebrow(
                    text: (session.brewedAt ?? Date()).formatted(date: .abbreviated, time: .omitted).uppercased(),
                    color: Constants.Colors.primaryColor.opacity(0.5)
                )
                Spacer()
                KRatingStars(rating: Double(session.rating), starSize: 10)
            }

            // Technique name
            Text(session.techniqueName ?? "Untitled")
                .font(Constants.Typography.display(20))
                .foregroundStyle(Constants.Colors.primaryColor)

            // Bean name
            if let beanName = session.beanName, !beanName.isEmpty {
                Text("with \(beanName)")
                    .font(Constants.Typography.sans(12))
                    .foregroundStyle(Constants.Colors.primaryColor.opacity(0.6))
            }

            // Notes quote
            if let notes = session.notes, !notes.isEmpty {
                Text("\u{201C}\(notes)\u{201D}")
                    .font(Constants.Typography.sans(14).italic())
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 52))
                .foregroundStyle(Constants.Colors.accentGold.opacity(0.5))
            Text("No brews yet")
                .font(Constants.Typography.display(24))
                .foregroundStyle(Constants.Colors.primaryColor)
            Text("Complete a brew to start your journal.")
                .font(Constants.Typography.sans(14))
                .foregroundStyle(Constants.Colors.primaryColor.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .adaptiveBackground()
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

    // MARK: - Week Helpers

    private struct WeekDay: Hashable {
        let label: String
        let brewed: Bool
    }

    private var weekDays: [WeekDay] {
        let calendar = Calendar.current
        let today = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return []
        }

        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        let brewDates = Set(viewModel.sessions.compactMap { session -> Int? in
            guard let date = session.brewedAt else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let weekStartDay = calendar.startOfDay(for: weekStart)
            let diff = calendar.dateComponents([.day], from: weekStartDay, to: dayStart).day ?? -1
            return (diff >= 0 && diff < 7) ? diff : nil
        })

        return (0..<7).map { dayOffset in
            WeekDay(label: labels[dayOffset], brewed: brewDates.contains(dayOffset))
        }
    }

    private var brewsThisWeek: Int {
        let calendar = Calendar.current
        let today = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return 0
        }
        return viewModel.sessions.filter { session in
            guard let date = session.brewedAt else { return false }
            return date >= weekStart && date <= today
        }.count
    }
}
