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
                Text("Snapdesk")
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
            
            // GitHub Link
            Button(action: {
                if let url = URL(string: "https://github.com/pedroknup/snapdesk") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 16, weight: .medium))
                    Text("github.com/pedroknup/snapdesk")
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            // Author and Credits
            VStack(spacing: 12) {
                HStack {
                    Text("**Author**")
                        .font(.headline)
                    Spacer()
                    Text("Pedro Knup")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("**License**")
                        .font(.headline)
                    Spacer()
                    Text("MIT License")
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: 400)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            
            // Attribution Section
            VStack(spacing: 12) {
                Text("**Acknowledgments**")
                    .font(.headline)
                
                Text("Heavily inspired by and built upon code from **Amethyst** by Ian Ynda-Hummel and contributors. Special thanks to the Amethyst project for pioneering tiling window management on macOS.")
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                
                Button(action: {
                    if let url = URL(string: "https://github.com/ianyh/Amethyst") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                        Text("View Amethyst Project")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1))
                    .foregroundColor(.secondary)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(12)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    AboutTabView()
}
