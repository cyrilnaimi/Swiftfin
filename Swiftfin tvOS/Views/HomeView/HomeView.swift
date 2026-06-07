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

    @StateObject
    private var viewModel = HomeViewModel()

    /// Layout strategy:
    ///
    /// - When the user has Resume items, keep the tvOS-signature cinematic
    ///   hero at the top (`CinematicResumeView`) followed by stacked rows.
    /// - Otherwise, fall back to a cinematic Recently Added hero (matching
    ///   upstream / the App Store build) — but only when it actually has
    ///   items: `CinematicItemSelector` renders its full-screen frame even
    ///   when empty, which pushed every subsequent row off-screen on fresh
    ///   accounts and made the home look blank.
    /// - With no hero at all, render only stacked poster rows
    ///   (Next Up → Recently Added → Latest per library).
    ///
    /// This is a separate struct (not a `contentView` property) so it can
    /// observe `recentlyAddedViewModel` directly — its items arrive after
    /// `HomeViewModel.state` flips to `.content`, and `HomeView` itself only
    /// re-renders on `HomeViewModel` changes.
    private struct ContentView: View {

        @ObservedObject
        var viewModel: HomeViewModel

        @ObservedObject
        var recentlyAddedViewModel: RecentlyAddedLibraryViewModel

        @Default(.Customization.Home.showRecentlyAdded)
        private var showRecentlyAdded

        var body: some View {
            let hasResumeHero = viewModel.resumeItems.isNotEmpty
            let hasRecentlyAddedHero = !hasResumeHero && showRecentlyAdded && recentlyAddedViewModel.elements.isNotEmpty

            ScrollView {
                VStack(alignment: .leading, spacing: 30) {

                    if hasResumeHero {
                        CinematicResumeView(viewModel: viewModel)
                    } else if hasRecentlyAddedHero {
                        CinematicRecentlyAddedView(viewModel: recentlyAddedViewModel)
                    }

                    NextUpView(viewModel: viewModel.nextUpViewModel)

                    // skip the row when Recently Added is already the hero
                    if showRecentlyAdded, !hasRecentlyAddedHero {
                        RecentlyAddedView(viewModel: recentlyAddedViewModel)
                    }

                    ForEach(viewModel.libraries) { viewModel in
                        LatestInLibraryView(viewModel: viewModel)
                    }
                }
                .padding(.top, hasResumeHero || hasRecentlyAddedHero ? 0 : 130)
                .padding(.bottom, 60)
            }
        }
    }

    var body: some View {
        ZStack {
            Color.clear

            switch viewModel.state {
            case .content:
                ContentView(
                    viewModel: viewModel,
                    recentlyAddedViewModel: viewModel.recentlyAddedViewModel
                )
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
