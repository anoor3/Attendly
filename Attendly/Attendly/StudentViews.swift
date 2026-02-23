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
                QRScannerSheet(onScanned: { code in
                    viewModel.handleScannedCode(code)
                })
            }
            .sheet(item: $viewModel.pendingEnrollment) { prompt in
                EnrollmentSheet(prompt: prompt) {
                    viewModel.confirmEnrollment(for: prompt)
                } onCancel: {
                    viewModel.cancelEnrollmentPrompt()
                }
            }
            .sheet(item: $viewModel.confirmation) { confirmation in
                AttendanceConfirmationView(message: confirmation.message, result: confirmation.result)
                    .presentationDetents([.fraction(0.4)])
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
        let radius = Int(viewModel.classes.first?.geofenceRadius ?? 30)
        return VStack(alignment: .leading, spacing: 12) {
            Label("Location requested once per scan", systemImage: "shield.lefthalf.fill")
                .font(.headline)
            Text("We never store raw GPS—only a verification stamp proving you're within the \(radius)m classroom radius.")
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
            let records = Array(viewModel.attendanceHistory.prefix(6))
            if records.isEmpty {
                Text("No check-ins yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(records, id: \.id) { record in
                    let sessionDate = record.timestamp.formatted(date: .abbreviated, time: .shortened)
                    TimelineRow(
                        title: viewModel.className(for: record),
                        subtitle: sessionDate,
                        status: viewModel.status(for: record)
                    )
                }
            }
        }
    }
}

struct QRScannerSheet: View {
    var onScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var didScan = false
    @State private var manualCode = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("Align QR to check in")
                .font(.title2.bold())
            QRCodeScannerView { code in
                guard !didScan else { return }
                didScan = true
                onScanned(code)
                dismiss()
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadowStyle(AttendlyDesignSystem.Shadows.card)
            Text("Location verification occurs once, on-device. Make sure you're within the classroom geofence.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            VStack(spacing: 12) {
                TextField("Paste QR payload", text: $manualCode)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                GradientButton(title: "Use typed code", icon: "doc.on.doc") {
                    guard !manualCode.isEmpty else { return }
                    onScanned(manualCode)
                    dismiss()
                }
            }
            #if targetEnvironment(simulator)
            GradientButton(title: "Simulate Success", icon: "checkmark.seal") {
                onScanned("simulated|0|token")
                dismiss()
            }
            #endif
        }
        .padding(AttendlyDesignSystem.Spacing.large)
        .presentationDetents([.fraction(0.7)])
    }
}

struct AttendanceConfirmationView: View {
    var message: String
    var result: AttendanceResult

    private var accent: Color {
        switch result {
        case .success, .alreadyCheckedIn: return AttendlyDesignSystem.Colors.success
        case .outsideGeofence, .invalid: return AttendlyDesignSystem.Colors.danger
        case .locked, .expired: return AttendlyDesignSystem.Colors.warning
        }
    }

    private var icon: String {
        switch result {
        case .success: return "checkmark.circle.fill"
        case .alreadyCheckedIn: return "checkmark.circle"
        case .locked: return "lock.circle.fill"
        case .expired: return "clock.badge.exclamationmark"
        case .outsideGeofence: return "location.slash"
        case .invalid: return "xmark.octagon.fill"
        }
    }

    private var detailText: String {
        switch result {
        case .success:
            return "You're marked present. Stay within range until the professor locks attendance."
        case .alreadyCheckedIn:
            return "You're already marked present. Check your history for confirmation."
        default:
            return "Please try again or contact your professor if this persists."
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 96))
                .symbolEffect(.bounce, value: message)
                .foregroundStyle(accent)
            Text(message)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(detailText)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(AttendlyDesignSystem.Spacing.large)
    }
}

struct EnrollmentSheet: View {
    let prompt: StudentHomeViewModel.EnrollmentPrompt
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: AttendlyDesignSystem.Spacing.large) {
            VStack(spacing: 8) {
                Text("Join \(prompt.payload.className)?")
                    .font(.title2.bold())
                Text("Section \(prompt.payload.section) • \(prompt.payload.semester)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Label("Room \(prompt.payload.room)", systemImage: "door.left.hand.closed")
                Label("Meets \(prompt.payload.meetingDays.joined(separator: " · "))", systemImage: "calendar")
                Label("Geofence \(Int(prompt.payload.geofenceRadius))m", systemImage: "mappin.and.ellipse")
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)

            GradientButton(title: "Join class & Check In", icon: "checkmark.circle.fill") {
                onConfirm()
            }
            Button("Cancel", role: .cancel) {
                onCancel()
            }
        }
        .padding(AttendlyDesignSystem.Spacing.large)
        .presentationDetents([.fraction(0.45)])
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
        let appState = AppState()
        StudentHomeView(viewModel: StudentHomeViewModel(appState: appState))
    }
}
