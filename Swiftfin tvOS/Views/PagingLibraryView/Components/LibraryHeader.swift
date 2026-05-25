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

    private var totalCount: Int {
        // Access totalCount - PagingLibraryViewModel conforms to HasTotalCount
        (viewModel as? HasTotalCount)?.totalCount ?? 0
    }

    @Router
    private var router

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(alignment: .center, spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("(\(totalCount) \(L10n.items.lowercased()))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 7)
                }

                Spacer()

                HStack(spacing: 30) {

                    FilterPillButton {
                        router.route(to: .filter(type: ItemFilterType.traits, viewModel: filterViewModel))
                    } label: {
                        Text(filterButtonTitle)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Text(L10n.by.lowercased())

                    FilterPillButton {
                        router.route(to: .filter(type: ItemFilterType.sortBy, viewModel: filterViewModel))
                    } label: {
                        Text(sortButtonTitle)
                    }

                    if filterViewModel.currentFilters.hasFilters {
                        FilterPillButton {
                            filterViewModel.send(.reset())
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle")
                                Text(L10n.reset)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(EdgeInsets(top: 10, leading: 60, bottom: 10, trailing: 60))
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

/// Matches the look of `ListRowButton` from Settings: grey rounded-rect fill,
/// focus brightens, `.buttonStyle(.card)` for native tvOS focus behavior.
/// Unlike `ListRowButton`, accepts arbitrary label content (so callers can use
/// HStack { Image; Text } for icon-bearing pills like Reset).
private struct FilterPillButton<Label: View>: View {

    @FocusState
    private var isFocused: Bool

    private let action: () -> Void
    private let label: () -> Label

    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(HierarchicalShapeStyle.secondary)
                    .brightness(isFocused ? 0.25 : 0)

                label()
                    .foregroundStyle(HierarchicalShapeStyle.primary)
                    .font(.body.weight(.bold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
        }
        .buttonStyle(.card)
        .fixedSize()
        .frame(maxHeight: 75)
        .focused($isFocused)
    }
}
