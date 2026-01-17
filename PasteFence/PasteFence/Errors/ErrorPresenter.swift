import Combine
import Foundation
import SwiftUI

// MARK: - Error Presenter

/// Centralized error presentation coordinator
/// Manages error display state and provides the bridge between errors and UI
@MainActor
public final class ErrorPresenter: ObservableObject {

    // MARK: - Singleton

    /// Shared instance for app-wide error presentation
    public static let shared = ErrorPresenter()

    // MARK: - Published State

    /// Current error message to display
    @Published public var currentError: UserErrorMessage?

    /// Current actions for the error
    @Published public var currentActions: [ErrorAction] = []

    /// Whether an error is currently being shown
    @Published public var isShowingError = false

    /// Whether showing as toast (auto-dismiss) vs modal (requires action)
    @Published public var isToast = false

    // MARK: - Dependencies

    private let messageProvider: ErrorMessageProvider

    // MARK: - Toast Timer

    private var toastDismissTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(messageProvider: ErrorMessageProvider = DefaultErrorMessageProvider()) {
        self.messageProvider = messageProvider
    }

    // MARK: - Presentation Methods

    /// Present an error as a modal alert (requires user action to dismiss)
    /// - Parameter error: The error to present
    public func present(_ error: Error) {
        toastDismissTask?.cancel()

        let message = messageProvider.userMessage(for: error)
        let actions = messageProvider.actions(for: error)

        currentError = message
        currentActions = actions
        isToast = false
        isShowingError = true

        // Log the error
        logPresenterError(error, message: message)
    }

    /// Present an error as a brief toast notification (auto-dismisses after delay)
    /// - Parameters:
    ///   - error: The error to present
    ///   - duration: How long to show the toast (default: 3 seconds)
    public func presentToast(_ error: Error, duration: TimeInterval = 3.0) {
        toastDismissTask?.cancel()

        let message = messageProvider.userMessage(for: error)

        currentError = message
        currentActions = []
        isToast = true
        isShowingError = true

        // Log the error
        logPresenterError(error, message: message)

        // Auto-dismiss after duration
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self?.dismiss()
            }
        }
    }

    /// Present an error with automatic style selection based on severity
    /// - Info/Warning: Toast style
    /// - Error/Critical: Modal style
    public func presentAuto(_ error: Error) {
        let message = messageProvider.userMessage(for: error)

        switch message.severity {
        case .info, .warning:
            presentToast(error)
        case .error, .critical:
            present(error)
        }
    }

    /// Dismiss the current error
    public func dismiss() {
        toastDismissTask?.cancel()
        isShowingError = false

        // Delay clearing the error to allow for animation
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            if !isShowingError {
                currentError = nil
                currentActions = []
            }
        }
    }

    // MARK: - Logging

    private func logPresenterError(_ error: Error, message: UserErrorMessage) {
        // Use structured logging via AppLogger
        AppLogger.shared.log(error, context: ErrorContext(
            file: #file,
            function: #function,
            line: #line,
            additionalInfo: ["userMessage": message.title]
        ))
    }
}

// MARK: - View Extension

extension View {
    /// Adds error alert presentation capability to a view
    /// Uses the shared ErrorPresenter to display errors
    public func errorAlert() -> some View {
        self.modifier(ErrorAlertModifier())
    }
}

// MARK: - Error Alert Modifier

/// View modifier that adds error alert presentation
struct ErrorAlertModifier: ViewModifier {
    @ObservedObject private var presenter = ErrorPresenter.shared

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $presenter.isShowingError) {
                if let error = presenter.currentError, !presenter.isToast {
                    ErrorAlertView(
                        message: error,
                        actions: presenter.currentActions,
                        onDismiss: { presenter.dismiss() }
                    )
                }
            }
            .overlay(alignment: .top) {
                if presenter.isToast, let error = presenter.currentError {
                    ToastView(message: error)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: presenter.isShowingError)
                        .onTapGesture {
                            presenter.dismiss()
                        }
                }
            }
    }
}

// MARK: - Toast View

/// Lightweight toast notification view
struct ToastView: View {
    let message: UserErrorMessage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: message.severity.symbolName)
                .font(.system(size: 20))
                .foregroundColor(severityColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(message.title)
                    .font(.headline)

                Text(message.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
        .padding(.horizontal)
        .padding(.top, 8)
        .accessibilityIdentifier("errorToast")
    }

    private var severityColor: Color {
        switch message.severity {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .red
        }
    }
}
