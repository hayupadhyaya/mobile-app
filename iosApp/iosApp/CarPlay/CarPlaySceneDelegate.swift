import Foundation
import CarPlay
import ComposeApp

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?
    private var kmpReadyObserver: NSObjectProtocol?

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        print("CP: Connected to CarPlay")

        // Koin/KMP is initialized when ContentView renders (MainViewController configure block).
        // CarPlay may connect before that, so check the shared flag first.
        if KmpState.isReady {
            setupTemplates()
        } else {
            kmpReadyObserver = NotificationCenter.default.addObserver(
                forName: KmpState.readyNotification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.setupTemplates()
                if let observer = self?.kmpReadyObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self?.kmpReadyObserver = nil
                }
            }
        }
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        if let observer = kmpReadyObserver {
            NotificationCenter.default.removeObserver(observer)
            kmpReadyObserver = nil
        }
        print("CP: Disconnected from CarPlay")
    }

    private func setupTemplates() {
        let libraryTemplate = createLibraryTemplate()
        interfaceController?.setRootTemplate(libraryTemplate, animated: true, completion: nil)
    }

    // MARK: - UI Construction

    // Match Material Design icons from LandingPage.kt LibraryRow
    // Icons.Default.Album, Icons.AutoMirrored.Filled.FeaturedPlayList,
    // Icons.AutoMirrored.Filled.MenuBook, Icons.Default.Radio
    private static let categoryIcons: [(name: String, symbol: String)] = [
        ("Albums", "opticaldisc.fill"),
        ("Playlists", "list.bullet.rectangle.fill"),
        ("Audiobooks", "book.fill"),
        ("Radio", "radio.fill"),
    ]

    // App theme colors (from Color.kt dark scheme)
    // primaryContainer (card bg) ≈ #404378, primary (icon) = #C0C1FF
    private static let cardBackground = UIColor(red: 0x40/255.0, green: 0x43/255.0, blue: 0x78/255.0, alpha: 1.0)
    private static let iconTint = UIColor(red: 0xC0/255.0, green: 0xC1/255.0, blue: 0xFF/255.0, alpha: 1.0)

    private func createLibraryTemplate() -> CPListTemplate {
        // Section 1: Browse categories as an image row
        let imageSize = CPListImageRowItem.maximumImageSize
        let categoryImages = Self.categoryIcons.map { icon -> UIImage in
            let symbol = UIImage(systemName: icon.symbol)!
            let renderer = UIGraphicsImageRenderer(size: imageSize)
            return renderer.image { ctx in
                // Fill entire rect; CarPlay applies its own corner rounding
                Self.cardBackground.setFill()
                ctx.fill(CGRect(origin: .zero, size: imageSize))

                // Draw SF Symbol centered, tinted with app's primary color
                let symbolConfig = UIImage.SymbolConfiguration(pointSize: imageSize.height * 0.4, weight: .medium)
                let configured = symbol.withConfiguration(symbolConfig)
                    .withTintColor(Self.iconTint, renderingMode: .alwaysOriginal)
                let symbolSize = configured.size
                let origin = CGPoint(
                    x: (imageSize.width - symbolSize.width) / 2,
                    y: (imageSize.height - symbolSize.height) / 2
                )
                configured.draw(at: origin)
            }
        }

        let browseRow = CPListImageRowItem(text: "Browse", images: categoryImages)
        browseRow.listImageRowHandler = { [weak self] _, index, completion in
            switch index {
            case 0: self?.pushAlbumsTemplate()
            case 1: self?.pushPlaylistsTemplate()
            case 2: self?.pushAudiobooksTemplate()
            case 3: self?.pushRadioTemplate()
            default: break
            }
            completion()
        }

        let browseSection = CPListSection(
            items: [browseRow],
            header: nil,
            sectionIndexTitle: nil
        )

        // Section 2: Recently Played (starts with loading placeholder)
        let loadingItem = CPListItem(text: "Loading...", detailText: nil)
        let recentSection = CPListSection(
            items: [loadingItem],
            header: "Recently Played",
            sectionIndexTitle: nil
        )

        let libraryList = CPListTemplate(title: "Library", sections: [browseSection, recentSection])

        // Async load recently played
        loadRecentlyPlayed(for: libraryList, browseSection: browseSection)

        return libraryList
    }

    // MARK: - Data Loading Helpers

    private func loadRecentlyPlayed(for template: CPListTemplate, browseSection: CPListSection) {
        CarPlayContentManager.shared.fetchRecommendations { items in
            self.attachHandlers(to: items)
            let recentSection: CPListSection
            if items.isEmpty {
                let emptyItem = CPListItem(text: "No recent items", detailText: nil)
                recentSection = CPListSection(items: [emptyItem], header: "Recently Played", sectionIndexTitle: nil)
            } else {
                recentSection = CPListSection(items: items, header: "Recently Played", sectionIndexTitle: nil)
            }
            template.updateSections([browseSection, recentSection])
        }
    }

    // MARK: - Navigation Helpers

    private func pushPlaylistsTemplate() {
        let listTemplate = CPListTemplate(title: "Playlists", sections: [])
        let loadingItem = CPListItem(text: "Loading...", detailText: nil)
        listTemplate.updateSections([CPListSection(items: [loadingItem])])

        self.interfaceController?.pushTemplate(listTemplate, animated: true, completion: nil)

        CarPlayContentManager.shared.fetchPlaylists { items in
            self.attachHandlers(to: items)
            listTemplate.updateSections([CPListSection(items: items)])
        }
    }

    private func pushAlbumsTemplate() {
        let listTemplate = CPListTemplate(title: "Albums", sections: [])
        let loadingItem = CPListItem(text: "Loading...", detailText: nil)
        listTemplate.updateSections([CPListSection(items: [loadingItem])])

        self.interfaceController?.pushTemplate(listTemplate, animated: true, completion: nil)

        CarPlayContentManager.shared.fetchAlbums { items in
            self.attachHandlers(to: items)
            listTemplate.updateSections([CPListSection(items: items)])
        }
    }

    private func pushArtistsTemplate() {
        let listTemplate = CPListTemplate(title: "Artists", sections: [])
        let loadingItem = CPListItem(text: "Loading...", detailText: nil)
        listTemplate.updateSections([CPListSection(items: [loadingItem])])

        self.interfaceController?.pushTemplate(listTemplate, animated: true, completion: nil)

        CarPlayContentManager.shared.fetchArtists { items in
            self.attachHandlers(to: items)
            listTemplate.updateSections([CPListSection(items: items)])
        }
    }

    private func pushAudiobooksTemplate() {
        let listTemplate = CPListTemplate(title: "Audiobooks", sections: [])
        let loadingItem = CPListItem(text: "Loading...", detailText: nil)
        listTemplate.updateSections([CPListSection(items: [loadingItem])])

        self.interfaceController?.pushTemplate(listTemplate, animated: true, completion: nil)

        CarPlayContentManager.shared.fetchAudiobooks { items in
            self.attachHandlers(to: items)
            listTemplate.updateSections([CPListSection(items: items)])
        }
    }

    private func pushRadioTemplate() {
        let listTemplate = CPListTemplate(title: "Radio", sections: [])
        let loadingItem = CPListItem(text: "Loading...", detailText: nil)
        listTemplate.updateSections([CPListSection(items: [loadingItem])])

        self.interfaceController?.pushTemplate(listTemplate, animated: true, completion: nil)

        CarPlayContentManager.shared.fetchRadioStations { items in
            self.attachHandlers(to: items)
            listTemplate.updateSections([CPListSection(items: items)])
        }
    }

    // MARK: - Item Selection

    private func attachHandlers(to items: [CPListItem]) {
        for item in items {
            item.handler = { [weak self] listItem, completion in
                self?.handleItemSelection(listItem)
                completion()
            }
        }
    }

    private func handleItemSelection(_ item: CPSelectableListItem) {
        if let cpListItem = item as? CPListItem,
           let mediaItem = cpListItem.userInfo as? AppMediaItem {
            CarPlayContentManager.shared.playItem(mediaItem)
            self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
        }
    }
}

