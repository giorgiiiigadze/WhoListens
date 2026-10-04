import SwiftUI

@MainActor
final class AppToastCenter: ObservableObject {
    static let shared = AppToastCenter()

    enum Style {
        case success, error, info

        var symbol: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .error: "exclamationmark.circle.fill"
            case .info: "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: Color(red: 0.30, green: 0.85, blue: 0.55)
            case .error: Color(red: 0.96, green: 0.29, blue: 0.29)
            case .info: AppColors.warmOrange
            }
        }
    }

    struct Toast: Identifiable {
        let id = UUID()
        let message: String
        let style: Style
    }

    @Published private(set) var current: Toast?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ message: String, style: Style = .info) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            current = Toast(message: message, style: style)
        }
        let id = current?.id
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled, current?.id == id else { return }
            dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        withAnimation(.easeOut(duration: 0.2)) { current = nil }
    }
}

struct AppToastOverlay: View {
    @ObservedObject private var center = AppToastCenter.shared

    var body: some View {
        VStack {
            if let toast = center.current {
                HStack(spacing: 12) {
                    Image(systemName: toast.style.symbol)
                        .foregroundStyle(toast.style.color)
                    Text(toast.message)
                        .font(AppTypography.body)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(toast.style.color.opacity(0.55), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .onTapGesture { center.dismiss() }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("\(toast.message). Dismiss notification")
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .allowsHitTesting(center.current != nil)
    }
}
