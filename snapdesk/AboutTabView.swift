//
//  AboutTabView.swift
//  snapdesk
//
//  Created by Pedro Knup on 20/04/2025.
//
import SwiftUI

struct AboutTabView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "app.fill")
                .resizable()
                .foregroundColor(Color.blue)
                .frame(width: 100, height: 100)
                .cornerRadius(20)

            Text("SnapDesk")
                .font(.system(size: 28, weight: .bold))

            Text("Version 0.0.1 (beta)")
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 100)

            VStack(spacing: 8) {
                HStack {
                    Text("**Author**")
                    Spacer()
                    Text("Pedro Knup")
                }

                HStack {
                    Text("**License**")
                    Spacer()
                    Text("Proprietary – All rights reserved")
                }
            }
            .frame(maxWidth: 400)
            .padding(.horizontal)

            Text("Efficient window management and smart layout control for power users on macOS.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)

            Button(action: {
                // dummy action
            }) {
                Text("Check for Updates")
            }
            .padding(.top, 12)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    AboutTabView()
}
