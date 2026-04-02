//
//  ContentView.swift
//  Watch Watch App
//
//  Created by yuman on 2026/4/2.
//

import WatchKit
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .onAppear {
            WKInterfaceDevice.current().play(.retry)
        }
    }
}
