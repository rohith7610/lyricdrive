import SwiftUI

@MainActor
@Observable
final class TabRouter {
    var selectedTab = 0

    func showLyricsTab() {
        selectedTab = 0
    }
}
