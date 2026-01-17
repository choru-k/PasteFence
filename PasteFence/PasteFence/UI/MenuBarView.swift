import SwiftUI

struct MenuBarView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 12) {
            // Status Header
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading) {
                    Text("PasteFence")
                        .font(.headline)
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            // Quick Stats
            if let lastMasked = coordinator.lastMaskedText {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Masked")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(lastMasked.prefix(100) + (lastMasked.count > 100 ? "..." : ""))
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
            }

            Divider()

            // Shortcut Hint
            HStack {
                Text("⌘⇧V")
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)

                Text("Mask & Paste")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding()
        .frame(width: 280)
    }

    private var statusText: String {
        if coordinator.isProcessing {
            return "Processing..."
        }
        return "Ready"
    }
}

#Preview {
    MenuBarView(coordinator: AppCoordinator())
}
