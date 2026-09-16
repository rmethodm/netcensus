import SwiftUI
import ScanEngine

struct SeverityBadge: View {
    var severity: Severity

    var body: some View {
        Text(severity.rawValue.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
            .accessibilityLabel("\(severity.rawValue) severity")
    }

    private var foreground: Color {
        switch severity {
        case .info: .secondary
        case .low: .blue
        case .medium: .orange
        case .high, .critical: .white
        }
    }

    private var background: Color {
        switch severity {
        case .info: Color.secondary.opacity(0.2)
        case .low: Color.blue.opacity(0.2)
        case .medium: Color.orange.opacity(0.25)
        case .high: .orange
        case .critical: .red
        }
    }
}
