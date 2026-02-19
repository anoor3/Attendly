//
//  AttendlyApp.swift
//  Attendly
//
//  Created by Abdullah Noor on 2/18/26.
//

import SwiftUI

@main
struct AttendlyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppState())
                .preferredColorScheme(.light)
        }
    }
}
