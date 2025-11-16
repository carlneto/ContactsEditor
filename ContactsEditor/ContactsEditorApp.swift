//
//  ContactsEditorApp.swift
//  ContactsEditor
//
//  Created by Carlos Neto on 28/10/2025.
//

import SwiftUI

@main
struct ContactsEditorApp: App {
   @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
   var body: some Scene {
      WindowGroup {
         ContentView()
            .frame(minWidth: 900, minHeight: 600)
      }
   }
}
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
