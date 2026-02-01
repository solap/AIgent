//
//  MainTabView.swift
//  AIgent
//
//  Created by Joel Dehlin on 1/31/26.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ContentView()
                .tabItem {
                    Image(systemName: "message")
                    Text("Chat")
                }
                .tag(0)

            ImageGenerationView()
                .tabItem {
                    Image(systemName: "photo.artframe")
                    Text("Image Gen")
                }
                .tag(1)
        }
    }
}

#Preview {
    MainTabView()
}
