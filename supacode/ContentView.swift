//
//  ContentView.swift
//  supacode
//
//  Created by khoi on 20/1/26.
//

import SwiftUI

struct ContentView: View {
    let runtime: GhosttyRuntime

    var body: some View {
        GhosttyTerminalView(runtime: runtime)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
    }
}
