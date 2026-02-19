import SwiftUI
import CoreImage.CIFilterBuiltins

struct GradientButton: View {
    var title: String
    var icon: String?
    var action: () -> Void
    @State private var animate = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.title3.bold())
                }
                Text(title)
                    .font(.title3.bold())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.headline.bold())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(
                AttendlyDesignSystem.gradientButtonBackground()
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .scaleEffect(animate ? 1.02 : 1)
            )
            .shadow(color: Color.blue.opacity(0.35), radius: 16, y: 12)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

struct HeroCard<Content: View>: View {
    var title: String
    var subtitle: String
    var live: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AttendlyDesignSystem.Spacing.medium) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text(subtitle)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                if live { LiveIndicator() }
            }
            content
        }
        .padding(AttendlyDesignSystem.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AttendlyDesignSystem.gradientButtonBackground()
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        )
        .foregroundStyle(.white)
        .shadow(color: Color.blue.opacity(0.25), radius: 30, y: 20)
    }
}

struct StatusPill: View {
    enum Status {
        case present, late, absent, info

        var label: String {
            switch self {
            case .present: return "Present"
            case .late: return "Late"
            case .absent: return "Absent"
            case .info: return "Info"
            }
        }

        var color: Color {
            switch self {
            case .present: return AttendlyDesignSystem.Colors.success
            case .late: return AttendlyDesignSystem.Colors.warning
            case .absent: return AttendlyDesignSystem.Colors.danger
            case .info: return AttendlyDesignSystem.Colors.info
            }
        }

        var icon: String {
            switch self {
            case .present: return "checkmark.circle.fill"
            case .late: return "clock.badge.exclamationmark"
            case .absent: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }

    var status: Status

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.icon)
            Text(status.label)
                .font(.caption.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(status.color.opacity(0.15))
        .foregroundStyle(status.color)
        .clipShape(Capsule())
    }
}

struct LiveIndicator: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.3))
                .frame(width: animate ? 26 : 16, height: animate ? 26 : 16)
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
        .accessibilityLabel("Live indicator")
    }
}

struct MetricCard: View {
    var title: String
    var value: String
    var delta: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text(delta)
                .font(.subheadline)
                .foregroundStyle(color)
        }
        .padding(AttendlyDesignSystem.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AttendlyDesignSystem.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadowStyle(AttendlyDesignSystem.Shadows.card)
    }
}

struct ProgressRingView: View {
    var progress: Double
    var statusText: String
    var status: StatusPill.Status

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.05), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AttendlyDesignSystem.gradientButtonBackground(),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: progress)
                VStack(spacing: 6) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    StatusPill(status: status)
                }
            }
            Text(statusText)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(AttendlyDesignSystem.Spacing.large)
        .frame(maxWidth: .infinity)
        .background(AttendlyDesignSystem.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadowStyle(AttendlyDesignSystem.Shadows.card)
    }
}

struct CountdownRingView: View {
    var duration: TimeInterval
    @Binding var elapsed: TimeInterval

    var body: some View {
        let progress = max(0, 1 - elapsed / duration)
        return ZStack {
            Circle()
                .stroke(Color.black.opacity(0.08), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AttendlyDesignSystem.gradientButtonBackground(),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * duration))s")
                .font(.headline.monospacedDigit())
        }
        .frame(width: 96, height: 96)
        .animation(.easeInOut(duration: 0.6), value: progress)
    }
}

struct DynamicQRView: View {
    var token: String

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        Image(uiImage: generateImage(from: token))
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AttendlyDesignSystem.Colors.card)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 25, y: 15)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private func generateImage(from string: String) -> UIImage {
        filter.message = Data(string.utf8)
        if let outputImage = filter.outputImage,
           let cgImage = context.createCGImage(outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10)), from: outputImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return UIImage(systemName: "qrcode") ?? UIImage()
    }
}

struct TimelineRow: View {
    var title: String
    var subtitle: String
    var status: StatusPill.Status

    var body: some View {
        HStack(spacing: 16) {
            VStack {
                Circle()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 10, height: 10)
                Rectangle()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 2)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusPill(status: status)
        }
        .padding(.vertical, 12)
    }
}

struct BottomActionBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                content
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .background(AttendlyDesignSystem.Colors.card)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct RoleSelectionCard: View {
    var role: UserRole
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(role.displayName)
                    .font(.title2.bold())
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AttendlyDesignSystem.Colors.success)
                }
            }
            Text(role == .professor ? "Command sessions, analytics, exports" : "Scan securely, view timelines")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isSelected ? Color.blue.opacity(0.08) : AttendlyDesignSystem.Colors.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    isSelected ? AnyShapeStyle(AttendlyDesignSystem.gradientButtonBackground()) : AnyShapeStyle(Color.black.opacity(0.08)),
                    lineWidth: 1.5
                )
        )
        .shadowStyle(AttendlyDesignSystem.Shadows.card)
    }
}
