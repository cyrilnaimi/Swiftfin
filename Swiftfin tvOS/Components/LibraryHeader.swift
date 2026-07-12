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
/// iOS `NavigationBarFilterDrawer` pattern: a title row stacked above a
/// horizontal scroll of capsule filter pills. Each pill opens its own selector
/// sheet (`NavigationRoute.filter`) and tints to the accent color when active.
struct LibraryHeader: View {

    // MARK: - Properties

    let title: String

    @ObservedObject
    var filterViewModel: FilterViewModel

    @Default(.accentColor)
    private var accentColor

    @Default(.Customization.Library.enabledDrawerFilters)
    private var enabledDrawerFilters

    private var hasActiveFilters: Bool {
        filterViewModel.currentFilters.isNotEmpty
    }

    @Router
    private var router

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding(.leading, 60)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(enabledDrawerFilters, id: \.self) { type in
                        FilterPillButton(
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
                        FilterPillButton(isActive: false, role: .destructive) {
                            filterViewModel.reset(filterType: nil)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                Text(L10n.reset)
                            }
                        }
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 20) // breathing room for the focus lift
            }
            .tint(accentColor)
            .focusSection()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Pill Title

    /// Each pill shows either its current selection summary (when active) or
    /// the filter-type display title (when inactive), matching the iOS drawer.
    private func pillTitle(for type: ItemFilterType) -> String {
        let filters = filterViewModel.currentFilters

        switch type {
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

/// Capsule-shaped filter pill modeled after the iOS `NavigationDrawerLabelStyle`:
/// thin material background, stroke outline, accent tint when active.
private struct FilterPillButton<Label: View>: View {

    let isActive: Bool
    var role: ButtonRole?
    let action: () -> Void
    @ViewBuilder
    let label: () -> Label

    var body: some View {
        Button(role: role, action: action) {
            label()
                .font(.callout.weight(.semibold))
                .foregroundStyle(textStyle)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .frame(minWidth: 100)
                .background {
                    Capsule()
                        .fill(backgroundStyle)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(strokeStyle, lineWidth: 1.5)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(FilterPillButtonStyle())
    }

    private var textStyle: AnyShapeStyle {
        if role == .destructive {
            return AnyShapeStyle(.tint)
        }
        return isActive ? AnyShapeStyle(.white) : AnyShapeStyle(.primary)
    }

    private var backgroundStyle: AnyShapeStyle {
        if isActive {
            return AnyShapeStyle(.tint)
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    private var strokeStyle: AnyShapeStyle {
        if isActive {
            return AnyShapeStyle(.tint.opacity(0.9))
        }
        return AnyShapeStyle(.white.opacity(0.18))
    }
}

/// Subtle tvOS focus style — scale up on focus without the heavy white card
/// chrome of `.buttonStyle(.card)`, keeping the capsule shape intact.
private struct FilterPillButtonStyle: ButtonStyle {

    @Environment(\.isFocused)
    private var isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .shadow(
                color: isFocused ? Color.black.opacity(0.35) : .clear,
                radius: isFocused ? 16 : 0,
                x: 0,
                y: isFocused ? 8 : 0
            )
            .brightness(isFocused ? 0.06 : 0)
            .animation(.snappy(duration: 0.18), value: isFocused)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
