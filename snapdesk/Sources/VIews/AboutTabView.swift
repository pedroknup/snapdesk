//
//  AboutTabView.swift
//  snapdesk
//
//  Created by Pedro Knup on 20/04/2025.
//
import SwiftUI

struct AboutTabView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Hero Section
                VStack(spacing: 20) {
                    // App Icon with Enhanced Shadow
                    Image("snapdesk-logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 128, height: 128)
                        .cornerRadius(26)
                        .shadow(color: .blue.opacity(0.25), radius: 20, x: 0, y: 8)
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                    
                    // App Name and Version with Better Typography
                    VStack(spacing: 6) {
                        Text("Snapdesk")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        HStack(spacing: 8) {
                            Text("Version 0.0.1")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text("BETA")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                    }
                    
                    // Enhanced Description with Value Proposition
                    VStack(spacing: 12) {
                        Text("Window management for macOS power users")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.primary)
                        
                        Text("The snapiest and most efficient way to organize windows on macOS. Built for developers, designers, and power users who demand efficiency.")
                            .font(.system(size: 15))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 16)
                
                // Support Section - Buy Me a Coffee (Strategic Placement)
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.pink)
                            .font(.system(size: 16))
                        Text("Love Snapdesk?")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    
                    Text("Help keep this project alive and support future features")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        if let url = URL(string: "https://buymeacoffee.com/pedroknup") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 16, weight: .medium))
                            Text("Buy me a coffee")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        if isHovered {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                
                // Action Buttons Row
                HStack(spacing: 16) {
                    // GitHub Button
                    Button(action: {
                        if let url = URL(string: "https://github.com/pedroknup/snapdesk") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 14, weight: .medium))
                            Text("Source Code")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        if isHovered {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    
                    // Documentation Button (placeholder)
                    Button(action: {
                        // Could link to docs when available
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 14, weight: .medium))
                            Text("Docs")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.green.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        if isHovered {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AboutTabView()
}
