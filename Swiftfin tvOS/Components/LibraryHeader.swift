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

extension EnvironmentValues {

    /// Set by `ItemLibraryBody` so the shared `PagingLibraryView` can draw the
    /// filter drawer as the first row of its scrolling content. Passing the
    /// view model rather than an erased view keeps the drawer's construction
    /// next to the grid it belongs to.
    @Entry
    var libraryFilterViewModel: FilterViewModel? = nil
}

/// The drawer, resolved from the environment — nothing for libraries that have
/// no filters, or when every drawer filter has been switched off in settings.
///
/// A view of its own rather than a property on `PagingLibraryView`: the value is
/// injected by `ItemLibraryBody`, which sits *between* `PagingLibraryView` and
/// its content, so an `@Environment` read declared on `PagingLibraryView`
/// resolves against its parent's environment and always comes back nil.
struct LibraryFilterDrawer: View {

    @Default(.Customization.Library.enabledDrawerFilters)
    private var enabledDrawerFilters

    @Environment(\.libraryFilterViewModel)
    private var filterViewModel

    var body: some View {
        if let filterViewModel, enabledDrawerFilters.isNotEmpty {
            LibraryHeader(filterViewModel: filterViewModel)
        }
    }
}

/// tvOS filter drawer. Upstream ships no tvOS filter UI (the tvOS branch of
/// `ItemLibraryBody` only renders a cinematic background), so this is entirely
/// local.
///
/// This used to be a horizontal scroll of one capsule pill per `ItemFilterType`,
/// mirroring the iOS `NavigationBarFilterDrawer`. Six pills is a lot of width and
/// a lot of vertical space for something that is mostly idle, and a pill only
/// shows its state through a tint, which was easy to miss on the TV. The row is
/// now a single button that opens `LibraryFilterMenu` — a stacked panel down the
/// leading edge, next to the sidebar, where active filters are an explicit list.
///
/// Deliberately renders no title: the shared `PagingLibraryView` draws the
/// library title as the first row of the same scrolling stack.
///
/// Drawn as the first row *inside* the library's `ScrollView` — it scrolls away
/// with the posters, and Up from the first poster row lands on it because that
/// move never leaves the scroll view.
struct LibraryHeader: View {

    // MARK: - Properties

    @ObservedObject
    var filterViewModel: FilterViewModel

    @Default(.accentColor)
    private var accentColor

    @Default(.Customization.Library.enabledDrawerFilters)
    private var enabledDrawerFilters

    @EnvironmentObject
    private var menuState: LibraryFilterMenuState

    /// Types with a selection, in the order the user arranged them in settings.
    private var activeTypes: [ItemFilterType] {
        enabledDrawerFilters.filter { filterViewModel.isFilterSelected(type: $0) }
    }

    /// What the trigger shows next to itself, so the current state is legible
    /// without opening the panel at all.
    private var activeSummary: String? {
        let summaries = activeTypes.compactMap { filterViewModel.summary(for: $0) }

        return summaries.isEmpty ? nil : summaries.joined(separator: " · ")
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 20) {
            Button {
                menuState.present()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.callout.weight(.bold))

                    Text(L10n.filters)

                    if activeTypes.isNotEmpty {
                        Text(activeTypes.count.description)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isActive ? accentColor : .white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 2)
                            .background {
                                Capsule().fill(isActive ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
                            }
                    }
                }
            }
            .buttonStyle(FilterTriggerButtonStyle(isActive: isActive))

            if let activeSummary {
                Text(activeSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .tint(accentColor)
        // Same `edgePadding` the poster grid applies, so the trigger and the first
        // poster share a leading edge.
        .padding(.horizontal, EdgeInsets.edgePadding)
        .padding(.vertical, 20) // breathing room for the focus lift
        .focusSection()
    }

    private var isActive: Bool {
        activeTypes.isNotEmpty
    }
}

/// Capsule trigger modeled after the iOS `NavigationDrawerLabelStyle`: thin
/// material background, stroke outline, accent fill when any filter is set.
private struct FilterTriggerButtonStyle: ButtonStyle {

    @Environment(\.isFocused)
    private var isFocused: Bool

    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(isActive ? AnyShapeStyle(.white) : AnyShapeStyle(HierarchicalShapeStyle.primary))
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background {
                Capsule()
                    .fill(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(Material.ultraThinMaterial))
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        isActive ? AnyShapeStyle(.tint.opacity(0.9)) : AnyShapeStyle(.white.opacity(0.18)),
                        lineWidth: 1.5
                    )
            }
            .contentShape(Capsule())
            .scaleEffect(isFocused ? 1.08 : 1)
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
