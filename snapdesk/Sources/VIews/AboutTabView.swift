//
//  AboutTabView.swift
//  snapdesk
//
//  Created by Pedro Knup on 20/04/2025.
//
import SwiftUI

struct AboutTabView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App Icon
            Image("snapdesk-logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .cornerRadius(24)
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // App Name and Version
            VStack(spacing: 8) {
                Text("SnapDesk")
                    .font(.system(size: 32, weight: .bold))
                
                Text("Version 0.0.1 (beta)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .padding(.horizontal, 100)
            
            // App Description
            Text("Efficient window management for power users on macOS.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .foregroundColor(.secondary)
            
            // Authors and License
            VStack(spacing: 12) {
                HStack {
                    Text("**Authors**")
                        .font(.headline)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Pedro Knup")
                    }
                }
                
                HStack {
                    Text("**License**")
                        .font(.headline)
                    Spacer()
                    Text("Proprietary – All rights reserved")
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: 400)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            
            // Update Button
            Button(action: {
                // dummy action
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Check for Updates")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    AboutTabView()
}
