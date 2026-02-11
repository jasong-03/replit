//
//  replitApp.swift
//  replit
//
//  Created by VBI2 on 11/2/26.
//

import SwiftUI
import SwiftData

@main
struct replitApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            UserProfile.self,
            AlarmItem.self,
            MeetingItem.self,
            MoodEntry.self,
            InboxItem.self,
            ScheduleBlock.self,
        ])
    }
}
