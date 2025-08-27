import SwiftUI

struct PreferencesView: View {
    @ObservedObject var viewModel: PreferencesViewModel
    @State private var hoveredTab: SettingsTab? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button(action: {
                        viewModel.selectedTab = tab
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: .regular))
                            Text(tab.title)
                                .font(.caption)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            viewModel.selectedTab == tab
                                ? Color.accentColor.opacity(0.25)
                                : (hoveredTab == tab ? Color.primary.opacity(0.1) : Color.clear)
                        )
                        .foregroundColor(viewModel.selectedTab == tab ? .primary : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        hoveredTab = hovering ? tab : nil
                    }
                }
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 6)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            Group {
                switch viewModel.selectedTab {
                case .settings:
                    SettingsTabView()
                case .shortcuts:
                    ShortcutsTabView()
                case .about:
                    AboutTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 700, minHeight: 740)
    }
}
