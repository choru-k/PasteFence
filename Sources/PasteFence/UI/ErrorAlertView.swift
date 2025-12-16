import SwiftUI

// MARK: - Error Alert View

/// Full error alert view for modal presentation
/// Displays error details with severity icon, description, suggestion, and action buttons
public struct ErrorAlertView: View {
    let message: UserErrorMessage
    let actions: [ErrorAction]
    let onDismiss: () -> Void

    public init(
        message: UserErrorMessage,
        actions: [ErrorAction] = [],
        onDismiss: @escaping () -> Void = {}
    ) {
        self.message = message
        self.actions = actions.isEmpty ? [ErrorAction(title: "OK", style: .primary)] : actions
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Severity icon
            Image(systemName: message.severity.symbolName)
                .font(.system(size: 48))
                .foregroundColor(severityColor)
                .accessibilityIdentifier("errorIcon")

            // Title
            Text(message.title)
                .font(.headline)
                .accessibilityIdentifier("errorTitle")

            // Description
            Text(message.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("errorDescription")

            // Suggestion (if available)
            if let suggestion = message.suggestion {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.blue)
                    Text(suggestion)
                        .font(.callout)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .accessibilityIdentifier("errorSuggestion")
            }

            // Error code (subtle display)
            if !message.errorCode.isEmpty {
                Text("Error code: \(message.errorCode)")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
                    .accessibilityIdentifier("errorCode")
            }

            // Action buttons
            actionButtons
                .padding(.top, 8)
        }
        .padding(24)
        .frame(minWidth: 320, maxWidth: 400)
        .accessibilityIdentifier("errorAlertView")
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        if actions.count == 1 {
            // Single button - full width
            actionButton(for: actions[0])
                .frame(minWidth: 120)
        } else {
            // Multiple buttons - horizontal stack
            HStack(spacing: 12) {
                ForEach(actions.indices, id: \.self) { index in
                    actionButton(for: actions[index])
                }
            }
        }
    }

    @ViewBuilder
    private func actionButton(for action: ErrorAction) -> some View {
        Button {
            action.handler()
            onDismiss()
        } label: {
            Text(action.title)
                .frame(minWidth: 80)
        }
        .buttonStyle(errorButtonStyle(for: action.style))
        .accessibilityIdentifier("errorAction_\(action.title.lowercased().replacingOccurrences(of: " ", with: "_"))")
    }

    private func errorButtonStyle(for style: ErrorAction.ActionStyle) -> some PrimitiveButtonStyle {
        switch style {
        case .primary:
            return AnyPrimitiveButtonStyle(DefaultButtonStyle())
        case .secondary:
            return AnyPrimitiveButtonStyle(BorderedButtonStyle())
        case .destructive:
            return AnyPrimitiveButtonStyle(DestructiveButtonStyle())
        }
    }

    // MARK: - Severity Color

    private var severityColor: Color {
        switch message.severity {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .red
        }
    }
}

// MARK: - Button Styles

/// Type-erased primitive button style
private struct AnyPrimitiveButtonStyle: PrimitiveButtonStyle {
    private let _makeBody: (Configuration) -> AnyView

    init<S: PrimitiveButtonStyle>(_ style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

/// Destructive button style (red background)
private struct DestructiveButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.trigger()
        } label: {
            configuration.label
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct ErrorAlertView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Critical error
            ErrorAlertView(
                message: UserErrorMessage(
                    title: "Critical Error",
                    description: "Failed to load model: The model file appears to be corrupted or incomplete.",
                    suggestion: "Try re-downloading the model from Settings.",
                    severity: .critical,
                    errorCode: "LLM003"
                ),
                actions: [
                    ErrorAction(title: "Re-download", style: .primary),
                    ErrorAction(title: "Cancel", style: .secondary)
                ]
            )
            .previewDisplayName("Critical Error")

            // Warning
            ErrorAlertView(
                message: UserErrorMessage(
                    title: "Warning",
                    description: "Input text exceeds the model's context length.",
                    suggestion: "Try with shorter text.",
                    severity: .warning,
                    errorCode: "LLM006"
                ),
                actions: [
                    ErrorAction(title: "OK", style: .primary)
                ]
            )
            .previewDisplayName("Warning")

            // Info
            ErrorAlertView(
                message: UserErrorMessage(
                    title: "Notice",
                    description: "Download completed successfully.",
                    severity: .info,
                    errorCode: ""
                )
            )
            .previewDisplayName("Info")
        }
    }
}
#endif
