//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
import SwiftUI

struct LibraryHeader<ViewModel: ObservableObject & AnyObject>: View {

    // MARK: - Properties

    let title: String
    @ObservedObject
    var viewModel: ViewModel
    @ObservedObject
    var filterViewModel: FilterViewModel

    @Default(.accentColor)
    private var accentColor

    private var totalCount: Int {
        (viewModel as? HasTotalCount)?.totalCount ?? 0
    }

    private var hasActiveFilters: Bool {
        filterViewModel.currentFilters.hasFilters
    }

    @Router
    private var router

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("(\(totalCount) \(L10n.items.lowercased()))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 30) {

                    FilterPillButton(isActive: hasActiveFilters) {
                        router.route(to: .filter(type: ItemFilterType.traits, viewModel: filterViewModel))
                    } label: {
                        Text(filterButtonTitle)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 600)
                    }

                    Text(L10n.by.lowercased())
                        .foregroundStyle(.secondary)

                    FilterPillButton(isActive: false) {
                        router.route(to: .filter(type: ItemFilterType.sortBy, viewModel: filterViewModel))
                    } label: {
                        Text(sortButtonTitle)
                    }

                    if hasActiveFilters {
                        FilterPillButton(isActive: true) {
                            filterViewModel.send(.reset())
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle")
                                    .imageScale(.medium)
                                    .symbolRenderingMode(.hierarchical)
                                Text(L10n.reset)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(EdgeInsets(top: 10, leading: 60, bottom: 10, trailing: 60))
            .tint(accentColor)
            .focusSection()

            if totalCount == 0 {
                Text(L10n.noResults)
                    .padding(.vertical, 100)
            }
        }
    }

    // MARK: - Computed Properties

    private var filterButtonTitle: String {
        let filters = filterViewModel.currentFilters
        var titles: [String] = []

        let traitOrder: [ItemTrait] = [.isUnplayed, .isPlayed, .isFavorite, .likes]

        for trait in traitOrder {
            if filters.traits.contains(trait) {
                titles.append(trait.displayTitle)
            }
        }

        let orderedTraits = Set(traitOrder)
        for trait in filters.traits where !orderedTraits.contains(trait) {
            titles.append(trait.displayTitle)
        }

        if !filters.genres.isEmpty {
            let genreNames = filters.genres.map(\.value)
            titles.append(contentsOf: genreNames)
        }

        if !filters.years.isEmpty {
            let yearNames = filters.years.map(\.value)
            titles.append(contentsOf: yearNames)
        }

        return titles.isEmpty ? L10n.all.capitalized : titles.joined(separator: " • ")
    }

    private var sortButtonTitle: String {
        let filters = filterViewModel.currentFilters
        if let sortBy = filters.sortBy.first {
            switch sortBy {
            case .name:
                return L10n.name.capitalized
            default:
                return sortBy.displayTitle
            }
        }
        return L10n.name.capitalized
    }
}

/// Pill-shaped filter / sort / reset button used in `LibraryHeader`.
///
/// Uses `.buttonStyle(.card)` for native tvOS focus behavior (scale + lift on
/// focus). Unfocused state shows a flat `secondarySystemFill` background so the
/// pill is visible against any library backdrop. When `isActive == true` the
/// pill tints to the inherited accent color to signal "has selected value".
private struct FilterPillButton<Label: View>: View {

    let isActive: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .font(.body.weight(.semibold))
                .foregroundStyle(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minWidth: 80)
                .background(Color.secondarySystemFill)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.card)
    }
}
