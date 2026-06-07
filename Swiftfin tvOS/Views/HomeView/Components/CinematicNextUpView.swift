//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

extension HomeView {

    struct CinematicNextUpView: View {

        @Router
        private var router

        @ObservedObject
        var viewModel: NextUpLibraryViewModel

        private func itemSelectorImageSource(for item: BaseItemDto) -> ImageSource {
            if item.type == .episode {
                item.seriesImageSource(
                    .logo,
                    maxWidth: UIScreen.main.bounds.width * 0.4,
                    maxHeight: 200
                )
            } else {
                item.imageSource(
                    .logo,
                    maxWidth: UIScreen.main.bounds.width * 0.4,
                    maxHeight: 200
                )
            }
        }

        var body: some View {
            // Cap the hero strip: a hero selector should only surface the
            // next few episodes, not the view model's whole first page.
            CinematicItemSelector(items: Array(viewModel.elements.elements.prefix(10))) { item in
                router.route(to: .item(item: item))
            }
            .topContent { item in
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
                    .frame(height: 200, alignment: .bottomLeading)
            }
            .content { item in
                // Series title + SxEx only — same info as the regular
                // Next Up row, never the episode name/still.
                VStack(alignment: .leading) {
                    Text(item.seriesName ?? item.displayTitle)
                        .font(.footnote.weight(.regular))
                        .foregroundColor(.primary)
                        .lineLimit(1, reservesSpace: true)

                    Text(item.seasonEpisodeLabel ?? .emptyDash)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1, reservesSpace: true)
                }
            }
        }
    }
}
