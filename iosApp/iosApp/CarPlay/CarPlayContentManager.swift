import Foundation
import CarPlay
import ComposeApp

// MARK: - Image Loader

class CarPlayImageLoader {
    static let shared = CarPlayImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private let session = URLSession.shared

    func loadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = urlString as NSString
        if let cached = cache.object(forKey: cacheKey) {
            completion(cached)
            return
        }

        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        session.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self?.cache.setObject(image, forKey: cacheKey)
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }
}

/// Manages data fetching for CarPlay using KmpHelper
class CarPlayContentManager {
    static let shared = CarPlayContentManager()

    private let dataSource = KmpHelper.shared.mainDataSource
    private let apiClient = KmpHelper.shared.serviceClient
    
    // MARK: - API Calls
    
    /// Fetch Recommendations (Recently Played / Home)
    func fetchRecommendations(completion: @escaping ([CPListItem]) -> Void) {
        // iOS KMP interop: access Flow via suspend function or callbacks wrapper
        // For simplicity in this plan, accessing request directly
        
        let request = Request.Library.shared.recommendations()
        
        apiClient.sendRequest(request: request) { result, error in
            guard let result = result else {
                print("CP: Error fetching recommendations: \(String(describing: error))")
                completion([])
                return
            }
            
            // Parse result to [ServerMediaItem] -> [AppMediaItem] -> [CPListItem]
            // This requires some manual bridging if not using KMP flow helpers
            
            // NOTE: In a full implementation we would use a proper KMP-Swift Flow collector
            // But for "Build Now", we use the callback approach
            
            // Assuming result can be cast/parsed.
            // Since `sendRequest` returns generic Result, we need to handle parsing.
            
            // Strategy: Use a helper on Kotlin side?
            // Or assume KMP generates ObjC generics properly?
            
            // Let's assume we get a list of objects we can map
            // Realistically, direct mapping from `Any?` in Swift is hard.
            // Better approach: Use KmpHelper to expose specific methods for Swift
            
            KmpHelper.shared.fetchRecommendations { items in
                let cpItems = items.compactMap { self.mapToCPListItem($0) }
                completion(cpItems)
            }
        }
    }
    
    func fetchPlaylists(completion: @escaping ([CPListItem]) -> Void) {
        KmpHelper.shared.fetchPlaylists { items in
            completion(items.compactMap { self.mapToCPListItem($0) })
        }
    }
    
    func fetchAlbums(completion: @escaping ([CPListItem]) -> Void) {
        KmpHelper.shared.fetchAlbums { items in
            completion(items.compactMap { self.mapToCPListItem($0) })
        }
    }
    
    func fetchArtists(completion: @escaping ([CPListItem]) -> Void) {
        KmpHelper.shared.fetchArtists { items in
            completion(items.compactMap { self.mapToCPListItem($0) })
        }
    }

    func fetchAudiobooks(completion: @escaping ([CPListItem]) -> Void) {
        KmpHelper.shared.fetchAudiobooks { items in
            completion(items.compactMap { self.mapToCPListItem($0) })
        }
    }

    func fetchTracks(completion: @escaping ([CPListItem]) -> Void) {
        KmpHelper.shared.fetchTracks { items in
            completion(items.compactMap { self.mapToCPListItem($0) })
        }
    }

    func fetchPodcasts(completion: @escaping ([CPListItem]) -> Void) {
        KmpHelper.shared.fetchPodcasts { items in
            completion(items.compactMap { self.mapToCPListItem($0) })
        }
    }

    func fetchRadioStations(completion: @escaping ([CPListItem]) -> Void) {
        KmpHelper.shared.fetchRadioStations { items in
            completion(items.compactMap { self.mapToCPListItem($0) })
        }
    }

    func fetchRecommendationFolders(completion: @escaping ([AppMediaItem.RecommendationFolder]) -> Void) {
        KmpHelper.shared.fetchRecommendationFolders { folders in
            completion(Array(folders))
        }
    }

    func search(query: String, completion: @escaping ([CPListItem]) -> Void) {
        KmpHelper.shared.search(query: query) { items in
             completion(items.compactMap { self.mapToCPListItem($0) })
        }
    }
    
    // MARK: - Action Handling
    
    func playItem(_ item: AppMediaItem) {
        // Trigger play via DataSource
        // We'll need to know which player is selected
        // For now, use the first available or last selected
        
        // This functionality needs KMP exposure too
        KmpHelper.shared.playMediaItem(item: item)
    }
    
    // MARK: - Helpers
    
    private func mapToCPListItem(_ item: AppMediaItem) -> CPListItem? {
        let title = item.name
        let subtitle = item.subtitle

        let listItem = CPListItem(text: title, detailText: subtitle)
        listItem.userInfo = item

        // Set type-appropriate placeholder icon
        let iconName: String
        if item is AppMediaItem.Audiobook {
            iconName = "book.fill"
        } else if item is AppMediaItem.RadioStation {
            iconName = "radio.fill"
        } else if item is AppMediaItem.Album {
            iconName = "square.stack"
        } else if item is AppMediaItem.Playlist {
            iconName = "music.note.list"
        } else if item is AppMediaItem.Artist {
            iconName = "person.2.crop.square.stack"
        } else {
            iconName = "music.note"
        }
        listItem.setImage(UIImage(systemName: iconName))

        // Load artwork asynchronously
        let serverUrl = KmpHelper.shared.getServerUrl()
        if let imageUrl = item.imageInfo?.url(serverUrl: serverUrl) {
            CarPlayImageLoader.shared.loadImage(from: imageUrl) { image in
                if let image = image {
                    listItem.setImage(image)
                }
            }
        }

        return listItem
    }
}
