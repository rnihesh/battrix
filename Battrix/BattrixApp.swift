//
//  BattrixApp.swift
//  Battrix
//
//  Created by Nihesh Rachakonda on 22/06/25.
//

import SwiftUI

@main
struct BattrixApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
