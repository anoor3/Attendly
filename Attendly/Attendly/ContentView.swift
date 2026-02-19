//
//  ContentView.swift
//  Attendly
//
//  Created by Abdullah Noor on 2/18/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var router = RoleRouterViewModel()
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let role = router.role {
                RoleExperienceView(role: role)
                    .environmentObject(appState)
                    .transition(.opacity)
            } else {
                RoleSelectionView(role: $router.role)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: router.role)
    }
}

private struct RoleSelectionView: View {
    @Binding var role: UserRole?
    @State private var selection: UserRole?

    var body: some View {
        VStack(spacing: AttendlyDesignSystem.Spacing.large) {
            Spacer()
            VStack(spacing: 12) {
                Text("Attendly")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Text("Enterprise attendance for modern campuses")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: AttendlyDesignSystem.Spacing.medium) {
                ForEach(UserRole.allCases) { option in
                    RoleSelectionCard(role: option, isSelected: selection == option)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                selection = option
                            }
                        }
                }
            }
            .padding(.horizontal, AttendlyDesignSystem.Spacing.large)

            GradientButton(title: selection == nil ? "Choose your role" : "Continue", icon: "arrow.right.circle.fill") {
                role = selection
            }
            .disabled(selection == nil)
            .opacity(selection == nil ? 0.5 : 1)
            .padding(.horizontal, AttendlyDesignSystem.Spacing.large)

            Text("Privacy-first: location is used only at check-in")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .background(
            ZStack {
                AttendlyDesignSystem.Colors.background
                RadialGradient(colors: [Color.blue.opacity(0.15), .clear], center: .top, startRadius: 10, endRadius: 600)
            }
            .ignoresSafeArea()
        )
    }
}

private struct RoleExperienceView: View {
    @EnvironmentObject var appState: AppState
    var role: UserRole

    var body: some View {
        switch role {
        case .professor:
            ProfessorExperienceView(appState: appState)
        case .student:
            StudentExperienceView(appState: appState)
        }
    }
}

private struct ProfessorExperienceView: View {
    @ObservedObject private var appState: AppState
    @StateObject private var viewModel: ProfessorDashboardViewModel

    init(appState: AppState) {
        self._appState = ObservedObject(wrappedValue: appState)
        _viewModel = StateObject(wrappedValue: ProfessorDashboardViewModel(appState: appState))
    }

    var body: some View {
        TabView {
            ProfessorDashboardView(viewModel: viewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "rectangle.grid.2x2")
                }
            ProfessorAnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.xaxis")
                }
            SettingsView(role: .professor)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .environmentObject(appState)
    }
}

private struct StudentExperienceView: View {
    @ObservedObject private var appState: AppState
    @StateObject private var viewModel: StudentHomeViewModel

    init(appState: AppState) {
        self._appState = ObservedObject(wrappedValue: appState)
        _viewModel = StateObject(wrappedValue: StudentHomeViewModel(appState: appState))
    }

    var body: some View {
        TabView {
            StudentHomeView(viewModel: viewModel)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            AttendanceHistoryView(summary: viewModel.profile.summary)
                .tabItem {
                    Label("History", systemImage: "clock")
                }
            SettingsView(role: .student)
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
        .environmentObject(appState)
    }
}

private struct ProfessorAnalyticsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AttendlyDesignSystem.Spacing.large) {
                    MetricCard(title: "Avg Attendance", value: "92%", delta: "+4% vs last term", color: AttendlyDesignSystem.Colors.success)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Compliance exports")
                            .font(.title3.bold())
                        Text("Generate CSV or PDF packets with timestamps, location verification flags, and late thresholds.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        GradientButton(title: "Export now", icon: "arrow.up.doc") {}
                    }
                    .padding(AttendlyDesignSystem.Spacing.large)
                    .background(AttendlyDesignSystem.Colors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadowStyle(AttendlyDesignSystem.Shadows.card)
                }
                .padding(AttendlyDesignSystem.Spacing.large)
            }
            .navigationTitle("Analytics")
        }
    }
}

private struct SettingsView: View {
    var role: UserRole

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AttendlyDesignSystem.Spacing.large) {
                    settingsSection(title: "Privacy") {
                        Toggle("Device binding", isOn: .constant(true))
                        Toggle("Biometric lock", isOn: .constant(false))
                    }
                    settingsSection(title: "Notifications") {
                        Toggle("Session reminders", isOn: .constant(true))
                        Toggle("Risk alerts", isOn: .constant(true))
                    }
                    settingsSection(title: role == .professor ? "Exports" : "Location") {
                        if role == .professor {
                            GradientButton(title: "Export CSV/PDF", icon: "arrow.up.doc") {}
                        } else {
                            Text("Location requested only during check-in. Nothing stored in background.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(AttendlyDesignSystem.Spacing.large)
            }
            .background(AttendlyDesignSystem.Colors.background)
            .navigationTitle("Settings")
        }
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.bold())
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .tint(.blue)
        }
        .padding(AttendlyDesignSystem.Spacing.large)
        .background(AttendlyDesignSystem.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadowStyle(AttendlyDesignSystem.Shadows.card)
    }
}

#Preview {
    ContentView()
}
