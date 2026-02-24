import Foundation
import Intents
import ComposeApp

class SiriIntentHandler: NSObject, INPlayMediaIntentHandling {

    // MARK: - Resolve

    func resolveMediaItems(for intent: INPlayMediaIntent, with completion: @escaping ([INPlayMediaMediaItemResolutionResult]) -> Void) {
        guard let query = intent.mediaSearch?.mediaName, !query.isEmpty else {
            completion([.unsupported()])
            return
        }

        guard KmpState.isReady else {
            completion([.unsupported()])
            return
        }

        KmpHelper.shared.search(query: query) { items in
            if items.isEmpty {
                completion([.unsupported()])
                return
            }

            let mediaItems = items.compactMap { Self.mapToINMediaItem($0) }
            if mediaItems.isEmpty {
                completion([.unsupported()])
            } else if mediaItems.count == 1 {
                completion([.success(with: mediaItems[0])])
            } else {
                completion([.disambiguation(with: mediaItems)])
            }
        }
    }

    // MARK: - Handle

    func handle(intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
        guard KmpState.isReady else {
            completion(INPlayMediaIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
            return
        }

        guard let selectedItem = intent.mediaItems?.first,
              let identifier = selectedItem.identifier else {
            completion(INPlayMediaIntentResponse(code: .failure, userActivity: nil))
            return
        }

        // Search again to find the matching AppMediaItem by itemId
        let query = intent.mediaSearch?.mediaName ?? ""
        KmpHelper.shared.search(query: query) { items in
            guard let match = items.first(where: { $0.itemId == identifier }) else {
                completion(INPlayMediaIntentResponse(code: .failure, userActivity: nil))
                return
            }

            KmpHelper.shared.playMediaItem(item: match)
            completion(INPlayMediaIntentResponse(code: .success, userActivity: nil))
        }
    }

    // MARK: - Mapping

    private static func mapToINMediaItem(_ item: AppMediaItem) -> INMediaItem? {
        let type: INMediaItemType
        if item is AppMediaItem.Track {
            type = .song
        } else if item is AppMediaItem.Album {
            type = .album
        } else if item is AppMediaItem.Artist {
            type = .artist
        } else if item is AppMediaItem.Playlist {
            type = .playlist
        } else if item is AppMediaItem.Audiobook {
            type = .audioBook
        } else if item is AppMediaItem.RadioStation {
            type = .radioStation
        } else if item is AppMediaItem.Podcast {
            type = .podcastShow
        } else {
            type = .song
        }

        return INMediaItem(
            identifier: item.itemId,
            title: item.name,
            type: type,
            artwork: nil,
            artist: item.subtitle
        )
    }
}
