//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
import SwiftUI

// MARK: - State

/// Presentation state for the library filter menu.
///
/// Shared between two views that cannot reach each other directly: the trigger
/// lives inside the library's scrolling content (so it scrolls away with the
/// posters, like the pills did), while the panel is mounted as an overlay on the
/// whole library body so it can span the full height next to the sidebar.
@MainActor
final class LibraryFilterMenuState: ObservableObject {

    enum Level: Hashable {
        case add
        case values(ItemFilterType)
    }

    @Published
    private(set) var isPresented = false

    /// Empty means the root level. Levels are pushed onto this, so `pop` is the
    /// Menu button's job and the panel never needs its own navigation stack —
    /// nesting one inside the app's would fight over the Menu press.
    @Published
    private(set) var path: [Level] = []

    var level: Level? {
        path.last
    }

    func present() {
        path = []
        isPresented = true
    }

    func push(_ level: Level) {
        path.append(level)
    }

    /// Pops one level, or dismisses the whole panel when already at the root.
    func popOrDismiss() {
        if path.isEmpty {
            isPresented = false
        } else {
            path.removeLast()
        }
    }

    func dismiss() {
        isPresented = false
        path = []
    }
}

// MARK: - Filter summaries

extension FilterViewModel {

    /// `itemTypes` and `query` are excluded: the former is a structural preset on
    /// the aggregate Movies/TV Shows tabs (`filters: .init(itemTypes:)`) and the
    /// latter belongs to search — neither is a user-chosen filter, so neither
    /// should make the menu report active filters.
    var hasUserFilters: Bool {
        var current = currentFilters
        current.itemTypes = ItemFilterCollection.default.itemTypes
        current.query = ItemFilterCollection.default.query

        return current != .default
    }

    /// Clears the user-chosen filters while preserving the structural `itemTypes`
    /// preset and any active search `query`.
    ///
    /// `reset(filterType: nil)` assigns `.default` wholesale, which drops
    /// `itemTypes` — on the Movies tab that turns the tab into an everything-tab.
    /// (Upstream's iOS drawer has the same problem.)
    func resetUserFilters() {
        var reset = ItemFilterCollection.default
        reset.itemTypes = currentFilters.itemTypes
        reset.query = currentFilters.query

        currentFilters = reset
    }

    /// The current selection for a filter type, or `nil` when nothing is selected.
    func summary(for type: ItemFilterType) -> String? {
        let filters = currentFilters

        switch type {
        case .genres:
            return joined(filters.genres.map(\.value))
        case .letter:
            return joined(filters.letter.map(\.value))
        case .sortBy:
            return filters.sortBy.first?.displayTitle
        case .tags:
            return joined(filters.tags.map(\.value))
        case .traits:
            guard filters.traits.isNotEmpty else { return nil }

            /// Stable, meaningful order rather than selection order.
            let traitOrder: [ItemTrait] = [.isUnplayed, .isPlayed, .isFavorite, .likes]
            var ordered = traitOrder
                .filter { filters.traits.contains($0) }
                .map(\.displayTitle)
            ordered += filters.traits
                .filter { !traitOrder.contains($0) }
                .map(\.displayTitle)

            return joined(ordered)
        case .years:
            return joined(filters.years.map(\.value))
        }
    }

    private func joined(_ values: [String]) -> String? {
        values.isEmpty ? nil : values.joined(separator: ", ")
    }
}

// MARK: - Menu

/// The panel, resolved from the environment — nothing for libraries that have no
/// filters, or when every drawer filter has been switched off in settings.
///
/// A view of its own rather than a property on `PagingLibraryView` for the same
/// reason `LibraryFilterDrawer` is: the view model is injected by
/// `ItemLibraryBody`, which sits *between* `PagingLibraryView` and its content,
/// so an `@Environment` read declared on `PagingLibraryView` resolves against its
/// parent's environment and always comes back nil.
struct LibraryFilterMenu: View {

    @Default(.Customization.Library.enabledDrawerFilters)
    private var enabledDrawerFilters

    @Environment(\.libraryFilterViewModel)
    private var filterViewModel

    @EnvironmentObject
    private var state: LibraryFilterMenuState

    var body: some View {
        if state.isPresented, let filterViewModel, enabledDrawerFilters.isNotEmpty {
            LibraryFilterMenuPanel(filterViewModel: filterViewModel)
        }
    }
}

private struct LibraryFilterMenuPanel: View {

    @ObservedObject
    var filterViewModel: FilterViewModel

    @Default(.accentColor)
    private var accentColor

    @Default(.Customization.Library.enabledDrawerFilters)
    private var enabledDrawerFilters

    @EnvironmentObject
    private var state: LibraryFilterMenuState

    private static let width: CGFloat = 620

    // MARK: - Filter types

    private var activeTypes: [ItemFilterType] {
        enabledDrawerFilters.filter { filterViewModel.isFilterSelected(type: $0) }
    }

    private var inactiveTypes: [ItemFilterType] {
        enabledDrawerFilters.filter { !filterViewModel.isFilterSelected(type: $0) }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            /// Keeps the grid readable behind the panel — the point of an overlay
            /// rather than a sheet is that the posters re-query in view while
            /// filters are being chosen.
            Color.black
                .opacity(0.45)
                .ignoresSafeArea()

            panel
        }
        // The Menu button walks back up the stack instead of leaving the library.
        .onExitCommand {
            state.popOrDismiss()
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .padding(.horizontal, 28)

            levelContent
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: Self.width, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Material.ultraThinMaterial)
                .background {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.black.opacity(0.55))
                }
        }
        // `SelectorView` is a `List`, which draws its focused row wider than the
        // rows around it and would otherwise bleed past the panel's edges.
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .padding(.vertical, 40)
        .padding(.leading, EdgeInsets.edgePadding)
        .tint(accentColor)
        // One focus unit, so leaving the panel is a deliberate Menu press rather
        // than a stray Right into the disabled grid.
        .focusSection()
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            /// The Menu button is what actually goes back; this is the affordance
            /// that says so, since nothing else on screen would.
            if state.path.isNotEmpty {
                Image(systemName: "chevron.backward")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Image(systemName: headerSystemImage)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(headerTitle)
                .font(.title3)
                .fontWeight(.semibold)
                .lineLimit(1)

            Spacer(minLength: 0)

            if state.path.isEmpty, activeTypes.isNotEmpty {
                Text(activeTypes.count.description)
                    .font(.headline)
                    .foregroundStyle(accentColor.overlayColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background {
                        Capsule().fill(accentColor)
                    }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 32)
        .padding(.bottom, 20)
    }

    private var headerTitle: String {
        switch state.level {
        case .none:
            L10n.filters
        case .add:
            L10n.add
        case let .values(type):
            type.displayTitle
        }
    }

    private var headerSystemImage: String {
        switch state.level {
        case .none:
            "line.3.horizontal.decrease"
        case .add:
            "plus"
        case let .values(type):
            type.systemImage
        }
    }

    // MARK: - Levels

    @ViewBuilder
    private var levelContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            /// A focusable way back, for the same reason `Close` exists on the root:
            /// the Menu press is not reliably ours on a tab root.
            if let previousLevelTitle {
                FilterMenuRow(
                    systemImage: "chevron.backward",
                    title: previousLevelTitle
                ) {
                    state.popOrDismiss()
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)
            }

            switch state.level {
            case .none:
                rootLevel
            case .add:
                addLevel
            case let .values(type):
                valuesLevel(for: type)
            }
        }
    }

    /// The level a back press returns to, named after it.
    private var previousLevelTitle: String? {
        switch state.path.count {
        case 0:
            nil
        case 1:
            L10n.filters
        default:
            L10n.add
        }
    }

    /// Active filters first, then the two ways forward, then the escape hatch.
    @ViewBuilder
    private var rootLevel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if activeTypes.isEmpty {
                    Text(L10n.none)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 8)
                } else {
                    sectionTitle(L10n.active)

                    ForEach(activeTypes) { type in
                        HStack(spacing: 10) {
                            FilterMenuRow(
                                systemImage: type.systemImage,
                                title: type.displayTitle,
                                subtitle: filterViewModel.summary(for: type),
                                accessory: .disclosure
                            ) {
                                state.push(.values(type))
                            }

                            /// A second focusable target rather than a gesture on
                            /// the row: Right from the row clears that one filter,
                            /// which is the fastest thing to want here.
                            FilterMenuRow(
                                systemImage: "xmark",
                                title: nil,
                                accessory: .none,
                                isCompact: true
                            ) {
                                filterViewModel.reset(filterType: type)
                            }
                        }
                        .padding(.horizontal, 28)
                    }
                }

                Divider()
                    .padding(.horizontal, 28)
                    .padding(.vertical, 6)

                if inactiveTypes.isNotEmpty {
                    FilterMenuRow(
                        systemImage: "plus.circle",
                        title: L10n.add,
                        accessory: .disclosure
                    ) {
                        state.push(.add)
                    }
                    .padding(.horizontal, 28)
                }

                if enabledDrawerFilters.contains(.sortBy) {
                    FilterMenuRow(
                        systemImage: ItemFilterType.sortBy.systemImage,
                        title: L10n.sort,
                        subtitle: filterViewModel.summary(for: .sortBy),
                        accessory: .disclosure
                    ) {
                        state.push(.values(.sortBy))
                    }
                    .padding(.horizontal, 28)
                }

                if filterViewModel.hasUserFilters {
                    FilterMenuRow(
                        systemImage: "arrow.counterclockwise",
                        title: L10n.reset,
                        isDestructive: true
                    ) {
                        filterViewModel.resetUserFilters()
                    }
                    .padding(.horizontal, 28)
                }

                /// An explicit way out. `onExitCommand` is best-effort here: the
                /// library is a tab root, and the Menu press can be taken by the
                /// tab/sidebar controller before SwiftUI sees it — the same
                /// priority problem the top tab bar had with upward exits.
                FilterMenuRow(
                    systemImage: "xmark",
                    title: L10n.close
                ) {
                    state.dismiss()
                }
                .padding(.horizontal, 28)
            }
            .padding(.vertical, 16)
        }
    }

    /// Only the types that are not already active — the list shrinks as filters
    /// are used, which is the whole reason "add" is its own level.
    @ViewBuilder
    private var addLevel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(inactiveTypes) { type in
                    FilterMenuRow(
                        systemImage: type.systemImage,
                        title: type.displayTitle,
                        accessory: .disclosure
                    ) {
                        state.push(.values(type))
                    }
                    .padding(.horizontal, 28)
                }
            }
            .padding(.vertical, 16)
        }
    }

    /// The same `SelectorView` the full-screen `FilterView` uses, so single vs
    /// multi select, checkmarks and the `sortBy` order/field split all behave
    /// exactly as they do on iOS.
    @ViewBuilder
    private func valuesLevel(for type: ItemFilterType) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if filterViewModel.isFilterSelected(type: type) {
                FilterMenuRow(
                    systemImage: "arrow.counterclockwise",
                    title: L10n.reset,
                    isDestructive: true
                ) {
                    filterViewModel.reset(filterType: type)
                }
                .padding(.horizontal, 28)
            }

            ForEach(type.group) { group in
                if type.group.count > 1 {
                    sectionTitle(group.displayTitle)
                }

                selector(group: group)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func selector(group: ItemFilterType.Group) -> some View {
        let source = filterViewModel.allFilters[keyPath: group.keyPath]

        let selectionBinding: Binding<[AnyItemFilter]> = Binding {
            filterViewModel.currentFilters[keyPath: group.keyPath]
        } set: {
            group.setter($0, filterViewModel)
        }

        if source.isEmpty {
            Text(L10n.none)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 28)
                .padding(.vertical, 8)
        } else {
            SelectorView(
                selection: selectionBinding,
                sources: source,
                type: group.selectorType
            )
            .listStyle(.plain)
            .padding(.horizontal, 14)
        }
    }

    @ViewBuilder
    private func sectionTitle(_ title: String) -> some View {
        Text(title.localizedUppercase)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 28)
            .padding(.top, 4)
    }
}

// MARK: - Row

/// A settings-style row: white fill and dark text on focus, matching
/// `ListRowMenu` so the panel reads as part of the same UI rather than a new one.
private struct FilterMenuRow: View {

    enum Accessory {
        case none
        case disclosure
    }

    let systemImage: String
    var title: String?
    var subtitle: String?
    var accessory: Accessory = .none
    var isDestructive: Bool = false
    var isCompact: Bool = false
    let action: () -> Void

    init(
        systemImage: String,
        title: String?,
        subtitle: String? = nil,
        accessory: Accessory = .none,
        isDestructive: Bool = false,
        isCompact: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
        self.isDestructive = isDestructive
        self.isCompact = isCompact
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.body)
                    .frame(width: 32)

                if let title {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        if let subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .opacity(0.75)
                        }
                    }

                    Spacer(minLength: 0)
                }

                if accessory == .disclosure {
                    Image(systemName: "chevron.forward")
                        .font(.caption.weight(.bold))
                        .opacity(0.6)
                }
            }
            .padding(.horizontal, isCompact ? 0 : 20)
            .padding(.vertical, 16)
            .frame(maxWidth: isCompact ? nil : .infinity, alignment: .leading)
            .frame(width: isCompact ? 72 : nil)
            .contentShape(Rectangle())
        }
        .buttonStyle(FilterMenuRowStyle(isDestructive: isDestructive))
    }
}

private struct FilterMenuRowStyle: ButtonStyle {

    @Environment(\.isFocused)
    private var isFocused: Bool

    let isDestructive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundStyle)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isFocused ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.08)))
            }
            .scaleEffect(isFocused ? 1.02 : 1)
            .animation(.snappy(duration: 0.15), value: isFocused)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }

    private var foregroundStyle: AnyShapeStyle {
        if isFocused {
            return AnyShapeStyle(isDestructive ? Color.red : .black)
        }
        return AnyShapeStyle(isDestructive ? AnyShapeStyle(Color.red) : AnyShapeStyle(HierarchicalShapeStyle.primary))
    }
}
