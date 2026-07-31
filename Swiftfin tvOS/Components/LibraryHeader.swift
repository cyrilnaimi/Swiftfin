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

/// tvOS filter drawer. Upstream ships no tvOS filter UI (the tvOS branch of
/// `ItemLibraryBody` only renders a cinematic background), so this mirrors the
/// iOS `NavigationBarFilterDrawer` pattern as a horizontal scroll of capsule
/// filter pills. Each pill opens its own selector sheet
/// (`NavigationRoute.filter`) and tints to the accent color when active.
///
/// Deliberately renders no title: the shared `PagingLibraryView` already sets a
/// `navigationTitle`, and drawing a second one here is what previously forced
/// hiding the whole nav bar — which stripped the top bar off Média→library
/// screens. Mounted as a `safeAreaBar` so `PagingLibraryView` can reserve grid
/// space for it via `IsSafeAreaBarApplied`.
struct LibraryHeader: View {

    // MARK: - Properties

    @ObservedObject
    var filterViewModel: FilterViewModel

    @Default(.accentColor)
    private var accentColor

    @Default(.Customization.Library.enabledDrawerFilters)
    private var enabledDrawerFilters

    /// `itemTypes` and `query` are excluded: the former is a structural preset
    /// on the aggregate Movies/TV Shows tabs (`filters: .init(itemTypes:)`) and
    /// the latter belongs to search — neither is a user-chosen filter, so
    /// neither should make the Reset pill appear.
    private var hasActiveFilters: Bool {
        var current = filterViewModel.currentFilters
        current.itemTypes = ItemFilterCollection.default.itemTypes
        current.query = ItemFilterCollection.default.query

        return current != .default
    }

    @Router
    private var router

    // MARK: - Body

    @ViewBuilder
    private var segmentDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.15))
            .frame(width: 1, height: 30)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(enabledDrawerFilters.enumerated()), id: \.element) { index, type in
                    if index > 0 {
                        segmentDivider
                    }

                    FilterSegmentButton(
                        isActive: filterViewModel.isFilterSelected(type: type)
                    ) {
                        router.route(to: .filter(type: type, viewModel: filterViewModel))
                    } label: {
                        HStack(spacing: 6) {
                            Text(pillTitle(for: type))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                                .opacity(0.75)
                        }
                    }
                }

                if hasActiveFilters {
                    segmentDivider

                    FilterSegmentButton(isActive: false, isDestructive: true, action: reset) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                            Text(L10n.reset)
                        }
                    }
                }
            }
            // Inner inset so a segment's highlight capsule never touches the
            // container's edge.
            .padding(4)
            .backport
            .glassEffect(.regular, in: .capsule)
            .padding(.vertical, 16)
            // Align the bar's leading edge with the poster grid's. The grid is a
            // CollectionVGrid that ignores the tvOS overscan safe area and insets
            // its content by a flat `edgePadding`; this bar is `safeAreaBar`
            // content, so it would otherwise sit at safe-area + our own padding
            // and land noticeably further right than the first poster.
            .padding(.horizontal, EdgeInsets.edgePadding)
        }
        .ignoresSafeArea(edges: .horizontal)
        .tint(accentColor)
        .focusSection()
    }

    // MARK: - Reset

    /// Clears the user-chosen filters while preserving the structural
    /// `itemTypes` preset and any active search `query`.
    ///
    /// `filterViewModel.reset(filterType: nil)` assigns `.default` wholesale,
    /// which drops `itemTypes` — on the Movies tab that turns the tab into an
    /// everything-tab. (Upstream's iOS drawer has the same problem.)
    private func reset() {
        var reset = ItemFilterCollection.default
        reset.itemTypes = filterViewModel.currentFilters.itemTypes
        reset.query = filterViewModel.currentFilters.query

        filterViewModel.currentFilters = reset
    }

    // MARK: - Pill Title

    /// Each pill shows either its current selection summary (when active) or
    /// the filter-type display title (when inactive), matching the iOS drawer.
    private func pillTitle(for type: ItemFilterType) -> String {
        let filters = filterViewModel.currentFilters

        switch type {
        case .category:
            let values = filters.categories.map(\.value)
            return values.isEmpty ? type.displayTitle : values.joined(separator: ", ")
        case .genres:
            let values = filters.genres.map(\.value)
            return values.isEmpty ? type.displayTitle : values.joined(separator: ", ")
        case .letter:
            let values = filters.letter.map(\.value)
            return values.isEmpty ? type.displayTitle : values.joined(separator: ", ")
        case .sortBy:
            if let first = filters.sortBy.first {
                return first.displayTitle
            }
            return type.displayTitle
        case .tags:
            let values = filters.tags.map(\.value)
            return values.isEmpty ? type.displayTitle : values.joined(separator: ", ")
        case .traits:
            if filters.traits.isEmpty {
                return type.displayTitle
            }
            let traitOrder: [ItemTrait] = [.isUnplayed, .isPlayed, .isFavorite, .likes]
            var ordered: [String] = []
            for trait in traitOrder where filters.traits.contains(trait) {
                ordered.append(trait.displayTitle)
            }
            for trait in filters.traits where !traitOrder.contains(trait) {
                ordered.append(trait.displayTitle)
            }
            return ordered.joined(separator: ", ")
        case .years:
            let values = filters.years.map(\.value)
            return values.isEmpty ? type.displayTitle : values.joined(separator: ", ")
        }
    }
}

/// A single segment of the filter bar. The bar itself owns the glass container;
/// each segment is its own focusable button that fills a capsule highlight when
/// focused, and the accent color when its filter is active.
private struct FilterSegmentButton<Label: View>: View {

    let isActive: Bool
    var isDestructive: Bool = false
    let action: () -> Void
    @ViewBuilder
    let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .contentShape(Capsule())
        }
        .buttonStyle(
            FilterSegmentButtonStyle(
                isActive: isActive,
                isDestructive: isDestructive
            )
        )
    }
}

/// Segment styling. Focus is shown by filling the segment rather than scaling
/// it: the segments sit inside a shared container, so a scale effect would push
/// neighbours around and overflow the container's edge.
private struct FilterSegmentButtonStyle: ButtonStyle {

    @Environment(\.isFocused)
    private var isFocused: Bool

    let isActive: Bool
    let isDestructive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundStyle)
            .background {
                Capsule().fill(backgroundStyle)
            }
            .animation(.snappy(duration: 0.18), value: isFocused)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }

    private var foregroundStyle: AnyShapeStyle {
        if isActive {
            AnyShapeStyle(.white)
        } else if isFocused {
            AnyShapeStyle(.black)
        } else if isDestructive {
            AnyShapeStyle(.tint)
        } else {
            AnyShapeStyle(.primary)
        }
    }

    private var backgroundStyle: AnyShapeStyle {
        if isActive {
            AnyShapeStyle(.tint)
        } else if isFocused {
            AnyShapeStyle(.white)
        } else {
            AnyShapeStyle(.clear)
        }
    }
}
