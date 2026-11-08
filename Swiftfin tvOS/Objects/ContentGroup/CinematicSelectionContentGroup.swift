//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import JellyfinAPI
import SwiftUI

struct CinematicSelectionContentGroup: ContentGroup {

    let id = "cinematic-selection"
    let viewModel: CinematicSelectionContentGroupViewModel

    var _shouldBeResolved: Bool {
        viewModel.hasContent
    }

    init(
        resumeLibrary: ResumeItemsLibrary,
        nextUpLibrary: NextUpLibrary,
        recentlyAddedLibrary: RecentlyAddedLibrary
    ) {
        self.viewModel = CinematicSelectionContentGroupViewModel(
            resumeLibrary: resumeLibrary,
            nextUpLibrary: nextUpLibrary,
            recentlyAddedLibrary: recentlyAddedLibrary
        )
    }

    func body(with viewModel: CinematicSelectionContentGroupViewModel) -> some View {
        SelectionView(viewModel: viewModel)
    }

    private struct SelectionView: View {

        @Environment(\.frameForParentView)
        private var frameForParentView

        @ObservedObject
        var viewModel: CinematicSelectionContentGroupViewModel

        @Router
        private var router

        private var parentFrame: CGRect {
            frameForParentView[.scrollView, default: .zero].frame
        }

        private func itemSelectorImageSource(for item: BaseItemDto) -> ImageSource {
            if item.type == .episode {
                item.imageSource(
                    itemID: item.seriesID,
                    .logo,
                    environment: ImageSourceOptions(
                        maxWidth: CinematicSelectionLayout.logoMaxWidth,
                        maxHeight: CinematicSelectionLayout.logoMaxHeight
                    )
                )
            } else {
                item.imageSource(
                    .logo,
                    environment: ImageSourceOptions(
                        maxWidth: CinematicSelectionLayout.logoMaxWidth,
                        maxHeight: CinematicSelectionLayout.logoMaxHeight
                    )
                )
            }
        }

        var body: some View {
            let items = viewModel.heroItems

            CinematicItemSelector(
                items: items
            ) { item in
                router.route(to: .item(item: item))
            } topContent: { item in
                ImageView(itemSelectorImageSource(for: item))
                    .placeholder { _ in
                        EmptyView()
                    }
                    .failure {
                        Text(item.displayTitle)
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                    }
                    .edgePadding(.leading)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: CinematicSelectionLayout.logoMaxHeight, alignment: .bottomLeading)
                    .frame(maxWidth: CinematicSelectionLayout.logoMaxWidth, alignment: .leading)
            }
            .preference(
                key: ContentGroupCustomizationKey.self,
                value: .ignoreSafeAreaTop
            )
        }
    }
}

/// The "Next Up" row. Skipped when Next Up has been promoted into the hero,
/// which happens whenever there is nothing mid-play — see `heroItems`.
struct CinematicNextUpContentGroup: ContentGroup {

    let id = "cinematic-next-up"
    let viewModel: CinematicSelectionContentGroupViewModel

    var _shouldBeResolved: Bool {
        viewModel.heroSource != .nextUp && viewModel.nextUpViewModel.elements.isNotEmpty
    }

    func body(with viewModel: CinematicSelectionContentGroupViewModel) -> some View {
        PosterHStackLibrarySection(
            viewModel: viewModel.nextUpViewModel,
            group: viewModel.nextUpGroup
        )
    }
}

/// The "Recently Added" row. Skipped when Recently Added is what the hero is
/// showing, so the same items never appear twice.
struct CinematicRecentlyAddedContentGroup: ContentGroup {

    let id = "cinematic-recently-added"
    let viewModel: CinematicSelectionContentGroupViewModel

    var _shouldBeResolved: Bool {
        viewModel.heroSource != .recentlyAdded && viewModel.recentlyAddedViewModel.elements.isNotEmpty
    }

    func body(with viewModel: CinematicSelectionContentGroupViewModel) -> some View {
        PosterHStackLibrarySection(
            viewModel: viewModel.recentlyAddedViewModel,
            group: viewModel.recentlyAddedGroup
        )
    }
}

final class CinematicSelectionContentGroupViewModel: ViewModel, WithRefresh {

    typealias Background = CinematicSelectionContentGroupViewModel

    /// Which library the hero is currently drawing from.
    enum HeroSource {
        case resume
        case nextUp
        case recentlyAdded
        case none
    }

    let nextUpGroup: PosterGroup<NextUpLibrary>
    let recentlyAddedGroup: PosterGroup<RecentlyAddedLibrary>
    let resumeViewModel: PagingLibraryViewModel<ResumeItemsLibrary>

    var nextUpViewModel: PagingLibraryViewModel<NextUpLibrary> {
        nextUpGroup.viewModel
    }

    var recentlyAddedViewModel: PagingLibraryViewModel<RecentlyAddedLibrary> {
        recentlyAddedGroup.viewModel
    }

    var background: CinematicSelectionContentGroupViewModel {
        get { self }
        set {}
    }

    var hasResumeItems: Bool {
        resumeViewModel.elements.isNotEmpty
    }

    /// Hero priority: Continue Watching, then Next Up, then Recently Added.
    ///
    /// Upstream skips straight from Continue Watching to Recently Added, so any
    /// account with nothing mid-play gets an unsorted grab-bag as the first
    /// thing on screen. Next Up is the far more useful "what do I watch now"
    /// answer, and Recently Added stays as the last resort so the hero is never
    /// empty. Recently Added is still reachable as a row below.
    var heroSource: HeroSource {
        if hasResumeItems {
            .resume
        } else if nextUpViewModel.elements.isNotEmpty {
            .nextUp
        } else if recentlyAddedViewModel.elements.isNotEmpty {
            .recentlyAdded
        } else {
            .none
        }
    }

    var heroItems: [BaseItemDto] {
        switch heroSource {
        case .resume:
            resumeViewModel.elements.elements
        case .nextUp:
            nextUpViewModel.elements.elements
        case .recentlyAdded:
            recentlyAddedViewModel.elements.elements
        case .none:
            []
        }
    }

    var hasContent: Bool {
        heroSource != .none
    }

    init(
        resumeLibrary: ResumeItemsLibrary,
        nextUpLibrary: NextUpLibrary,
        recentlyAddedLibrary: RecentlyAddedLibrary
    ) {
        self.resumeViewModel = PagingLibraryViewModel(library: resumeLibrary, pageSize: 20)
        self.nextUpGroup = PosterGroup(library: nextUpLibrary)
        self.recentlyAddedGroup = PosterGroup(library: recentlyAddedLibrary)

        super.init()

        resumeViewModel.objectWillChange
            .merge(with: nextUpViewModel.objectWillChange)
            .merge(with: recentlyAddedViewModel.objectWillChange)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func refresh() {
        Task {
            await refresh()
        }
    }

    func refresh() async {
        async let resume: Void = resumeViewModel.refresh()
        async let nextUp: Void = nextUpViewModel.refresh()
        async let recentlyAdded: Void = recentlyAddedViewModel.refresh()

        _ = await (resume, nextUp, recentlyAdded)
    }
}

private enum CinematicSelectionLayout {

    static let logoMaxHeight: CGFloat = 100
    static let logoMaxWidth: CGFloat = 450
}
