// PermissionCheckView.swift
// GlazerAI
//
// SwiftUI view shown on launch when Screen Recording permission is missing.
// Polls permission state every second; enables Hide once access is granted.

import SwiftUI

/// Permission request UI presented when screen recording access is missing.
struct PermissionCheckView: View {

    // MARK: - Properties

    let service: ScreenRecordingPermissionService
    let onHide: () -> Void
    let onQuit: () -> Void

    @State private var isGranted: Bool

    private let statusTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    // MARK: - Init

    init(
        service: ScreenRecordingPermissionService,
        onHide: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.service = service
        self.onHide = onHide
        self.onQuit = onQuit
        _isGranted = State(initialValue: service.isGranted)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Title
            Text("Screen Recording Required")
                .font(.title2)
                .fontWeight(.semibold)

            // Description
            Text(
                "Glazer AI needs Screen Recording permission to capture regions " +
                "of your screen. Please grant access in System Settings to continue."
            )
            .font(.body)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            // Live permission status
            HStack(spacing: 8) {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(isGranted ? .green : .orange)
                    .font(.system(size: 16))
                Text(isGranted ? "Permission granted — you're all set!" : "Permission not granted")
                    .font(.callout)
                    .foregroundColor(isGranted ? .green : .secondary)
            }

            // Open System Settings button (hidden once granted)
            if !isGranted {
                Button("Open System Settings") {
                    service.requestAccess()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }

            Divider()

            // Bottom action row
            HStack {
                Button("Quit") { onQuit() }
                    .foregroundColor(.red)

                Spacer()

                Button("Hide") { onHide() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isGranted)
            }
        }
        .padding(24)
        .frame(width: 380)
        .onReceive(statusTimer) { _ in
            isGranted = service.isGranted
        }
    }
}
