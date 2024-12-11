//
//  StreamCancelApp.swift
//  StreamCancel
//
//  Created by John Siracusa on 12/11/24.
//

import SwiftUI

@main
struct StreamCancelApp: App {
    @State var consumer = Consumer()

    var body: some Scene {
        WindowGroup {
            ContentView(consumer: consumer)
        }
    }
}
