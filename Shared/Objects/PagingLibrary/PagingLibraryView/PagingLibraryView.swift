//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import CollectionVGrid
import Defaults
import SwiftUI

#if os(tvOS)
/// Scroll target for a repeated tab selection. Sits on the whole scrolling
/// stack rather than on the first element, so "back to top" lands on the filter
/// drawer and not on the first poster row below it. File scope because a
/// generic type cannot hold a static stored property.
private let libraryTopAnchorID = "paging-library-top"
#endif

struct PagingLibraryView<Library: PagingLibrary>: View where Library.Element: LibraryElement {

    typealias Element = Library.Element

    @Default(.Customization.Library.rememberLayout)
    private var rememberIndividualLibraryStyle
    @Default(.Customization.Library.style)
    private var defaultLibraryStyle

    @Namespace
    private var namespace

    @Router
    private var router

    @State
    private var isSafeAreaBarApplied: Bool = false

    @StateObject
    private var gridProxy = CollectionVGridProxy()
    @StateObject
    private var viewModel: PagingLibraryViewModel<Library>

    @StoredValue
    private var parentLibraryStyle: LibraryStyle

    @TabItemSelected
    private var tabItemSelected

    private var libraryStyleOptions: LibraryStyleOptions {
        viewModel.libraryStyleOptions
    }

    private var libraryStyle: LibraryStyle {
        libraryStyleOptions.normalized(storedLibraryStyle)
    }

    private var isLibraryStyleSectionVisible: Bool {
        libraryStyleOptions.hasVisibleControls ||
            (
                libraryStyle.displayType == .list &&
                    UIDevice.isPad &&
                    libraryStyleOptions.displayTypes.contains(.list)
            )
    }

    private var storedLibraryStyle: LibraryStyle {
        rememberIndividualLibraryStyle ? parentLibraryStyle : defaultLibraryStyle
    }

    private var storedLibraryStyleBinding: Binding<LibraryStyle> {
        rememberIndividualLibraryStyle ? $parentLibraryStyle : $defaultLibraryStyle
    }

    /// tvOS only: whether the library draws its own title above the grid, in
    /// place of the navigation bar's. The main-bar tabs pass `false` — they show
    /// no title today and the tab bar already names them.
    private let showsInlineTitle: Bool

    init(library: Library, showsInlineTitle: Bool = true) {
        self.showsInlineTitle = showsInlineTitle
        self._parentLibraryStyle = StoredValue(.User.libraryStyle(id: library.parent.pagingLibraryID))
        self._viewModel = StateObject(wrappedValue: PagingLibraryViewModel(library: library))
    }

    @ViewBuilder
    private var elementsView: some View {
        #if os(tvOS)
        scrollingElementsView
            .scrollIndicators(.hidden)
            .withViewContext(.isListRowSeparatorVisible)
            .withViewContext(.isThumb)
        #else
        collectionElementsView
            .scrollIndicators(.hidden)
            .withViewContext(.isListRowSeparatorVisible)
            .withViewContext(.isThumb)
            .onReceive(tabItemSelected) { event in
                if event.isRepeat, event.isRoot {
                    gridProxy.scrollToTop(animated: true)
                }
            }
        #endif
    }

    @ViewBuilder
    private var collectionElementsView: some View {
        AlternateLayoutView {
            Color.clear
        } content: { frame in

            let insets: EdgeInsets = if #available(iOS 26, *), isSafeAreaBarApplied {
                frame.safeAreaInsets + 10
            } else {
                .zero + 10
            }

            CollectionVGrid(
                uniqueElements: viewModel.displayedElements,
                layout: Element.layout(
                    for: libraryStyle,
                    options: libraryStyleOptions,
                    insets: insets
                )
            ) { element in
                element.makeBody(libraryStyle: libraryStyle)
            }
            .onReachedBottomEdge(offset: .offset(300)) {
                if viewModel.isSearchActive {
                    viewModel.getNextSearchPage()
                } else {
                    viewModel.getNextPage()
                }
            }
            .proxy(gridProxy)
            .ignoresSafeArea(edges: .vertical)
        }
    }

    #if os(tvOS)

    /// The library title, drawn in the content instead of the navigation bar.
    ///
    /// tvOS keeps a navigation bar title pinned over the grid, so on a pushed
    /// library — Média→library, or a home row's title button — it sat on top of
    /// the posters scrolling past it. The bar is hidden on tvOS (see `body`) and
    /// the title drawn here instead, so it scrolls away with the pills.
    ///
    /// Suppressed on the main-bar tabs, which are title-less today — the tab bar
    /// already names them and `TabItem` hides their navigation bar upstream.
    /// `router.isRootOfPath` cannot make that call: it reports `true` on a pushed
    /// library too (verified on the sim), since a pushed route gets its own
    /// coordinator with an empty path.
    @ViewBuilder
    private var inlineTitleView: some View {
        if showsInlineTitle {
            Text(viewModel.library.parent.displayTitle)
                .font(.largeTitle)
                .fontWeight(.bold)
                .lineLimit(1)
                .padding(.horizontal, EdgeInsets.edgePadding)
                .padding(.top, 20)
        }
    }

    /// Whether the grid — and with it the drawer that scrolls inside it — is
    /// what `stateView` is currently drawing.
    private var isShowingElements: Bool {
        guard viewModel.state == .content else { return false }
        guard !(viewModel.isSearchActive && viewModel.background.is(.searching)) else { return false }

        return viewModel.displayedElements.isNotEmpty
    }

    /// tvOS browses with a native `ScrollView` instead of `CollectionVGrid`.
    ///
    /// The filter drawer has to live *inside* the scrolling content: it scrolls
    /// away with the posters like the main menu bar does, and — the part a
    /// mounted bar could never give — Up from the first poster row reaches the
    /// pills, because that move stays inside one scroll view instead of being a
    /// hand-off to a separate focus group, which the tab bar wins.
    ///
    /// `CollectionVGrid` cannot host a header (its sibling `CollectionVList`
    /// can; the grid cannot), and its insets cannot be animated open and shut
    /// either — any layout change there triggers a full `snapshotReload`. Hence
    /// the swap, kept to tvOS so iOS keeps upstream's collection view.
    ///
    /// The grid stays lazy; only the wrapping `VStack` is eager, so the drawer
    /// is always materialized and therefore always focusable.
    @ViewBuilder
    private var scrollingElementsView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    inlineTitleView

                    LibraryFilterDrawer()

                    LazyVGrid(
                        columns: gridColumns,
                        spacing: EdgeInsets.edgePadding
                    ) {
                        ForEach(viewModel.displayedElements) { element in
                            element.makeBody(libraryStyle: libraryStyle)
                                .onAppear {
                                    elementDidAppear(element)
                                }
                        }
                    }
                    .padding(.horizontal, EdgeInsets.edgePadding)
                    .padding(.top, 10)
                    .padding(.bottom, EdgeInsets.edgePadding)
                }
                .id(libraryTopAnchorID)
            }
            .onReceive(tabItemSelected) { event in
                if event.isRepeat, event.isRoot {
                    withAnimation {
                        scrollProxy.scrollTo(libraryTopAnchorID, anchor: .top)
                    }
                }
            }
        }
    }

    /// Mirrors the tvOS branch of `LibraryElement.layout(for:options:insets:)`,
    /// which is what `CollectionVGrid` was given: 4 columns landscape, 7
    /// otherwise, `edgePadding` between items and lines.
    private var gridColumnCount: Int {
        switch libraryStyle.displayType {
        case .grid:
            libraryStyle.posterDisplayType == .landscape ? 4 : 7
        case .list:
            max(1, libraryStyle.listColumnCount)
        }
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(),
                spacing: EdgeInsets.edgePadding,
                alignment: .top
            ),
            count: gridColumnCount
        )
    }

    /// Paging trigger, replacing `onReachedBottomEdge`: ask for the next page
    /// two rows out rather than on the very last element, so the request is in
    /// flight before the user arrives.
    private func elementDidAppear(_ element: Element) {
        let elements = viewModel.displayedElements

        guard let index = elements.index(id: element.id),
              index >= elements.count - gridColumnCount * 2 else { return }

        if viewModel.isSearchActive {
            guard !viewModel.background.is(.gettingNextSearchPage) else { return }
            viewModel.getNextSearchPage()
        } else {
            guard !viewModel.background.is(.gettingNextPage) else { return }
            viewModel.getNextPage()
        }
    }
    #endif

    @ViewBuilder
    private var menuContent: some View {
        if isLibraryStyleSectionVisible {
            LibraryStyleSection(
                libraryStyle: storedLibraryStyleBinding,
                options: libraryStyleOptions
            )
        }

        viewModel.library.makeMenuContent(environment: $viewModel.environment)

        Button(L10n.random, systemImage: "dice.fill") {
            viewModel.getRandomItem()
        }
    }

    @ViewBuilder
    private var stateView: some View {
        switch viewModel.state {
        case .initial, .refreshing:
            ProgressView()
        case .content:
            if viewModel.isSearchActive, viewModel.background.is(.searching) {
                ProgressView()
            } else if viewModel.displayedElements.isEmpty {
                ContentUnavailableView(
                    viewModel.isSearchActive ? L10n.noResults.localizedCapitalized : L10n.noItems.localizedCapitalized,
                    systemImage: viewModel.isSearchActive ? "magnifyingglass" : "rectangle.on.rectangle.slash"
                )
            } else {
                elementsView
            }
        case .error:
            viewModel.error.map(ErrorView.init)
        }
    }

    var body: some View {
        viewModel.library.makeLibraryBody(viewModel: viewModel) {
            #if os(tvOS)
            VStack(alignment: .leading, spacing: 0) {
                // Title and drawer normally ride inside the grid's scroll view.
                // Those states replace the grid, so they have to be pinned above
                // them instead — otherwise a filter that returns nothing takes
                // the pills off screen with it and there is no way to undo it.
                if !isShowingElements {
                    inlineTitleView

                    LibraryFilterDrawer()
                }

                ZStack {
                    stateView
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            #else
            ZStack {
                stateView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #endif
        }
        .animation(.linear(duration: 0.2), value: viewModel.background.is(.gettingNextPage))
        .animation(.linear(duration: 0.2), value: viewModel.background.is(.searching))
        .animation(.linear(duration: 0.2), value: viewModel.elements)
        .animation(.linear(duration: 0.2), value: viewModel.searchElements)
        .navigationTitle(viewModel.library.parent.displayTitle)
        #if os(tvOS)
            // The title moves into the scrolling content (`inlineTitleView`). Left
            // in the navigation bar it stays pinned over the posters passing under
            // it — the same complaint as the drawer, one layer up. The main-bar tabs
            // already hide this bar in `TabItem.library`; this extends it to pushed
            // libraries, which are the ones that carry a title.
                .toolbar(.hidden, for: .navigationBar)
        #endif
                .onPreferenceChange(IsSafeAreaBarApplied.self) { newValue in
                    isSafeAreaBarApplied = newValue
                }
                .backport
                .toolbarTitleDisplayMode(router.isRootOfPath ? .inlineLarge : .inline)
                .backport
                .onChange(of: viewModel.environment) {
                    viewModel.refreshForEnvironmentChange()
                }
                .backport
                .onChange(of: libraryStyle) { oldStyle, newStyle in
                    if Element.layout(for: oldStyle, options: libraryStyleOptions, insets: .zero) ==
                        Element.layout(for: newStyle, options: libraryStyleOptions, insets: .zero)
                    {
                        gridProxy.layout()
                    }
                }
                .onReceive(viewModel.events) { event in
                    switch event {
                    case let .gotRandomItem(element):
                        element.libraryDidSelectElement(router: router, in: namespace)
                    }
                }
                .onFirstAppear {
                    viewModel.refresh()
                }
        #if os(iOS)
                .navigationBarMenuButton(
                    isLoading: viewModel.background.is(.gettingNextPage) || viewModel.background.is(.gettingNextSearchPage)
                ) {
                    menuContent
                }
        #endif
    }
}
