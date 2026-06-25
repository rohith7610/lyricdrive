import SwiftUI

struct ShazamPermissionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onContinue: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.pink)

                Text("Identify Songs with Shazam")
                    .font(.title2.bold())

                Text("LyricDrive uses Shazam to identify the song playing around you, then loads matching lyrics.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                Text("Audio is processed on-device via Apple ShazamKit. Nothing is uploaded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                Button("Continue") {
                    dismiss()
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Shazam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

enum ShazamPermissionGate {
    private static let seenKey = "hasSeenShazamExplainer"

    static var hasSeenExplainer: Bool {
        UserDefaults.standard.bool(forKey: seenKey)
    }

    static func markSeen() {
        UserDefaults.standard.set(true, forKey: seenKey)
    }
}
