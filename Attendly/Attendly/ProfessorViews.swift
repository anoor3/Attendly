import SwiftUI
import UIKit

struct ProfessorDashboardView: View {
    @StateObject var viewModel: ProfessorDashboardViewModel
    @State private var elapsed: TimeInterval = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AttendlyDesignSystem.Spacing.large) {
                    classPicker
                    heroCard
                    liveSessionModule
                    analyticsStack
                    riskHighlights
                }
                .padding(.horizontal, AttendlyDesignSystem.Spacing.large)
                .padding(.vertical, AttendlyDesignSystem.Spacing.large)
                .background(AttendlyDesignSystem.Colors.background)
            }
            .navigationTitle("Professor")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showCreateClassSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                BottomActionBar {
                    GradientButton(title: "Export CSV + PDF", icon: "doc.badge.arrow.up") {
                        // Hook export service here
                    }
                }
            }
        }
        .background(AttendlyDesignSystem.Colors.background.ignoresSafeArea())
        .task(id: viewModel.qrToken) { elapsed = 0 }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard viewModel.liveSession != nil else { return }
            withAnimation(.easeInOut(duration: 0.6)) { elapsed += 1 }
        }
        .sheet(isPresented: $viewModel.showCreateClassSheet) {
            ClassFormSheet { form in
                viewModel.createClass(from: form)
                viewModel.showCreateClassSheet = false
            }
        }
    }

    private var classPicker: some View {
        HStack {
            Text("Classes")
                .font(.headline)
            Spacer()
            if viewModel.classes.isEmpty {
                Button("Create class") {
                    viewModel.showCreateClassSheet = true
                }
                .buttonStyle(.borderedProminent)
            } else {
                Menu {
                    ForEach(viewModel.classes) { attendlyClass in
                        Button(attendlyClass.name) {
                            viewModel.selectedClassId = attendlyClass.id
                        }
                    }
                    Divider()
                    Button("Create new class", systemImage: "plus") {
                        viewModel.showCreateClassSheet = true
                    }
                } label: {
                    Label(viewModel.activeClass?.name ?? "Select", systemImage: "building.columns")
                }
            }
        }
    }

    private var heroCard: some View {
        HeroCard(
            title: viewModel.activeClass?.name ?? "No Class",
            subtitle: "Room \(viewModel.activeClass?.room ?? "—") • \(viewModel.activeClass?.meetingDays.joined(separator: " · ") ?? "Schedule")",
            live: viewModel.liveSession != nil
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Semester \(viewModel.activeClass?.semester ?? "—")")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Text("Geofence \(Int(viewModel.activeClass?.geofenceRadius ?? 30))m • QR window \(Int(viewModel.qrWindow))s")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    @ViewBuilder
    private var liveSessionModule: some View {
        if viewModel.liveSession != nil {
            LiveSessionPanel(viewModel: viewModel, elapsed: $elapsed)
        } else {
            VStack(spacing: AttendlyDesignSystem.Spacing.medium) {
                Text("Kick off your class with a live QR session. We rotate codes every window and lock attendance when you end the session.")
                    .font(.title3)
                    .foregroundStyle(.primary)
                GradientButton(title: "Start Live Session", icon: "bolt.fill") {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        viewModel.startSession()
                    }
                }
            }
            .padding(AttendlyDesignSystem.Spacing.large)
            .background(AttendlyDesignSystem.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadowStyle(AttendlyDesignSystem.Shadows.card)
        }
    }

    private var analyticsStack: some View {
        HStack(spacing: AttendlyDesignSystem.Spacing.medium) {
            MetricCard(title: "Attendance", value: "94%", delta: "+3.1% WoW", color: AttendlyDesignSystem.Colors.success)
            MetricCard(title: "Late", value: "6", delta: "-1 vs avg", color: AttendlyDesignSystem.Colors.warning)
        }
    }

    private var riskHighlights: some View {
        VStack(alignment: .leading, spacing: AttendlyDesignSystem.Spacing.small) {
            HStack {
                Text("Risk students")
                    .font(.title3.bold())
                Spacer()
                StatusPill(status: .late)
            }
            ForEach(0..<3) { index in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Student \(index + 1)")
                            .font(.headline)
                        Text("67% attendance • Section A")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "exclamationmark.shield")
                        .foregroundStyle(AttendlyDesignSystem.Colors.warning)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(AttendlyDesignSystem.Colors.card)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadowStyle(AttendlyDesignSystem.Shadows.card)
            }
        }
    }
}

private struct LiveSessionPanel: View {
    @ObservedObject var viewModel: ProfessorDashboardViewModel
    @Binding var elapsed: TimeInterval

    var body: some View {
        VStack(spacing: AttendlyDesignSystem.Spacing.medium) {
            HStack {
                Text("Live session")
                    .font(.title2.bold())
                LiveIndicator()
                Spacer()
                Button(role: .destructive) {
                    withAnimation(.spring()) { viewModel.endSession() }
                } label: {
                    Text("End")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AttendlyDesignSystem.Colors.danger.opacity(0.1))
                        .foregroundStyle(AttendlyDesignSystem.Colors.danger)
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DynamicQRView(token: viewModel.qrToken)
                .frame(maxWidth: .infinity)
            Button {
                UIPasteboard.general.string = viewModel.qrToken
            } label: {
                Label("Copy token", systemImage: "doc.on.doc")
                    .font(.caption.bold())
            }

            HStack(alignment: .center, spacing: AttendlyDesignSystem.Spacing.medium) {
                CountdownRingView(duration: viewModel.qrWindow, elapsed: $elapsed)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Attendance")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.attendanceCount)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text("students checked in")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            VStack(spacing: 12) {
                ForEach(0..<3) { index in
                    HStack {
                        Text("Student \(index + 1)")
                            .font(.subheadline)
                        Spacer()
                        StatusPill(status: index == 0 ? .present : .late)
                    }
                }
            }
        }
        .padding(AttendlyDesignSystem.Spacing.large)
        .background(AttendlyDesignSystem.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadowStyle(AttendlyDesignSystem.Shadows.card)
        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
    }
}

struct ClassFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var form = ClassFormInput()
    var onSubmit: (ClassFormInput) -> Void

    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $form.name)
                    TextField("Section", text: $form.section)
                    TextField("Semester", text: $form.semester)
                    TextField("Room", text: $form.room)
                }
                Section("Schedule") {
                    ForEach(weekdays, id: \.self) { day in
                        Toggle(day, isOn: Binding(
                            get: { form.meetingDays.contains(day) },
                            set: { isOn in
                                if isOn {
                                    if !form.meetingDays.contains(day) {
                                        form.meetingDays.append(day)
                                    }
                                } else {
                                    form.meetingDays.removeAll { $0 == day }
                                }
                            }
                        ))
                    }
                }
                Section("Geofence") {
                    Stepper("Radius \(Int(form.geofenceRadius))m", value: $form.geofenceRadius, in: 10...200, step: 5)
                    TextField("Latitude", value: $form.coordinate.latitude, format: .number)
                    TextField("Longitude", value: $form.coordinate.longitude, format: .number)
                }
            }
            .navigationTitle("New Class")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSubmit(form)
                        dismiss()
                    }
                    .disabled(form.name.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}

struct ProfessorDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        let appState = AppState()
        ProfessorDashboardView(viewModel: ProfessorDashboardViewModel(appState: appState))
    }
}
