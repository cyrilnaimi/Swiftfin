//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import Foundation
import JellyfinAPI
import SwiftUI

struct HomeView: View {

    @Router
    private var router

    @StateObject
    private var viewModel = HomeViewModel()

    @Default(.Customization.Home.showRecentlyAdded)
    private var showRecentlyAdded

    // MARK: - Library shortcuts (always-visible fallback)

    //
    // Without this, the Home tab can render completely blank when the user has
    // no resume items, no Next Up, no Recently Added, and every library returns
    // zero "latest" items. The library shortcuts give the user a guaranteed
    // entry point regardless of recent activity.
    @ViewBuilder
    private var librariesShortcut: some View {
        let libraries: [BaseItemDto] = viewModel.libraries.compactMap { $0.parent as? BaseItemDto }
        if libraries.isNotEmpty {
            PosterHStack(
                title: L10n.libraries,
                type: .landscape,
                items: libraries
            ) { item in
                let viewModel = ItemLibraryViewModel(parent: item, filters: .default)
                router.route(to: .library(viewModel: viewModel))
            }
        }
    }

    /// Layout strategy:
    ///
    /// - When the user has Resume items, keep the tvOS-signature cinematic
    ///   hero at the top (`CinematicResumeView`) followed by stacked rows.
    /// - Otherwise, render only stacked poster rows (Next Up → Recently Added
    ///   → Latest per library → Libraries). The cinematic recently-added
    ///   variant was forcing a `UIScreen.bounds.height - 75` frame that pushed
    ///   every subsequent row off-screen — so on a fresh account with no
    ///   resume items, the home looked blank even though all data had loaded.
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {

                if viewModel.resumeItems.isNotEmpty {
                    CinematicResumeView(viewModel: viewModel)
                }

                NextUpView(viewModel: viewModel.nextUpViewModel)

                if showRecentlyAdded {
                    RecentlyAddedView(viewModel: viewModel.recentlyAddedViewModel)
                }

                ForEach(viewModel.libraries) { viewModel in
                    LatestInLibraryView(viewModel: viewModel)
                }

                librariesShortcut
            }
            .padding(.top, viewModel.resumeItems.isNotEmpty ? 0 : 130)
            .padding(.bottom, 60)
        }
    }

    var body: some View {
        ZStack {
            Color.clear

            switch viewModel.state {
            case .content:
                contentView
            case let .error(error):
                ErrorView(error: error)
            case .initial, .refreshing:
                ProgressView()
            }
        }
        .animation(.linear(duration: 0.1), value: viewModel.state)
        .refreshable {
            viewModel.send(.refresh)
        }
        .onFirstAppear {
            viewModel.send(.refresh)
        }
        .ignoresSafeArea()
        .sinceLastDisappear { interval in
            if interval > 60 || viewModel.notificationsReceived.contains(.itemMetadataDidChange) {
                viewModel.send(.backgroundRefresh)
                viewModel.notificationsReceived.remove(.itemMetadataDidChange)
            }
        }
    }
}
