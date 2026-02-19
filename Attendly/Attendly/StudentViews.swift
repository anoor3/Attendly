import SwiftUI

struct StudentHomeView: View {
    @StateObject var viewModel: StudentHomeViewModel
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AttendlyDesignSystem.Spacing.large) {
                    hero
                    scanButton
                    privacyCard
                    historyTimeline
                }
                .padding(AttendlyDesignSystem.Spacing.large)
            }
            .background(AttendlyDesignSystem.Colors.background)
            .navigationTitle("Student")
            .sheet(isPresented: $viewModel.isScanning) {
                QRScannerSheet(confirmAction: viewModel.confirmAttendance)
            }
            .sheet(isPresented: Binding(
                get: { viewModel.confirmationMessage != nil },
                set: { _ in viewModel.confirmationMessage = nil }
            )) {
                if let message = viewModel.confirmationMessage {
                    AttendanceConfirmationView(message: message)
                        .presentationDetents([.fraction(0.4)])
                }
            }
            .sheet(isPresented: $showHistory) {
                AttendanceHistoryView(summary: viewModel.profile.summary)
            }
        }
    }

    private var hero: some View {
        ProgressRingView(
            progress: viewModel.attendanceProgress,
            statusText: viewModel.attendanceProgress >= 0.7 ? "On track for credit" : "At risk — speak to advisor",
            status: viewModel.attendanceProgress >= 0.7 ? .present : .late
        )
    }

    private var scanButton: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily check-in")
                .font(.headline)
            GradientButton(title: "Scan to Check In", icon: "qrcode.viewfinder") {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    viewModel.isScanning = true
                }
            }
        }
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Location requested once per scan", systemImage: "shield.lefthalf.fill")
                .font(.headline)
            Text("We never store raw GPS—only a verification stamp proving you're within the \(Int(viewModel.profile.classes.first?.geofenceRadius ?? 30))m classroom radius.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(AttendlyDesignSystem.Spacing.large)
        .background(AttendlyDesignSystem.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadowStyle(AttendlyDesignSystem.Shadows.card)
    }

    private var historyTimeline: some View {
        VStack(alignment: .leading, spacing: AttendlyDesignSystem.Spacing.medium) {
            HStack {
                Text("History")
                    .font(.title2.bold())
                Spacer()
                Button("View All") {
                    showHistory = true
                }
                .buttonStyle(.bordered)
            }
            ForEach(0..<6) { index in
                TimelineRow(
                    title: "Session \(index + 1)",
                    subtitle: "Room 201 • \(Date.now.addingTimeInterval(Double(-index) * 86400).formatted(date: .abbreviated, time: .shortened))",
                    status: index == 2 ? .late : .present
                )
            }
        }
    }
}

struct QRScannerSheet: View {
    var confirmAction: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var scanning = true

    var body: some View {
        VStack(spacing: 24) {
            Text("Align QR to check in")
                .font(.title2.bold())
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .stroke(AttendlyDesignSystem.gradientButtonBackground(), lineWidth: 4)
                    .frame(height: 220)
                    .overlay(
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 80))
                            .foregroundStyle(.primary.opacity(0.2))
                    )
                if !scanning {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(AttendlyDesignSystem.Colors.success)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            Text("Location verification occurs once, on-device. Make sure you're within the classroom geofence.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            GradientButton(title: "Simulate Success", icon: "checkmark.seal") {
                withAnimation(.spring()) {
                    scanning = false
                    confirmAction(true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        dismiss()
                    }
                }
            }
        }
        .padding(AttendlyDesignSystem.Spacing.large)
        .presentationDetents([.fraction(0.7)])
    }
}

struct AttendanceConfirmationView: View {
    var message: String

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 96))
                .symbolEffect(.bounce, value: message)
                .foregroundStyle(AttendlyDesignSystem.Colors.success)
            Text(message)
                .font(.title2.bold())
            Text("You're marked present. Stay within range until the professor locks attendance.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(AttendlyDesignSystem.Spacing.large)
    }
}

struct AttendanceHistoryView: View {
    var summary: AttendanceSummary

    var body: some View {
        NavigationStack {
            List {
                Section("This Semester") {
                    historyRow(title: "On time", value: summary.onTimeCount, color: AttendlyDesignSystem.Colors.success)
                    historyRow(title: "Late", value: summary.lateCount, color: AttendlyDesignSystem.Colors.warning)
                    historyRow(title: "Absent", value: summary.absentCount, color: AttendlyDesignSystem.Colors.danger)
                }
                Section("Recent") {
                    ForEach(0..<10) { index in
                        HStack {
                            Text("Session \(index + 1)")
                            Spacer()
                            StatusPill(status: index % 3 == 0 ? .late : .present)
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }

    private func historyRow(title: String, value: Int, color: Color) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value)")
                .font(.headline)
                .foregroundStyle(color)
        }
    }
}

struct StudentHomeView_Previews: PreviewProvider {
    static var previews: some View {
        StudentHomeView(viewModel: .init(profile: SampleData.student))
    }
}
