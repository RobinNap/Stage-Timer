//
//  ContentView.swift
//  Stage Timer
//
//  Created by Robin Nap on 05/12/2024.
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif

import SwiftUI
import MessageUI

struct ContentView: View {
    @State private var timeRemaining: TimeInterval = 45 * 60
    @State private var initialTime: TimeInterval = 45 * 60
    @State private var isRunning = false
    @State private var showingSettings = false
    @State private var isVisible = true
    @State private var schedule: [Act] = []
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let flashTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    let scheduleTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @StateObject private var calendarManager = CalendarManager()
    @State private var lastTouchTime = Date()
    @State private var showControls = false
    let controlTimeout: TimeInterval = 5 // 5 seconds
    let controlTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @Environment(\.scenePhase) private var scenePhase
    
    private var currentAct: Act? {
        let now = Date()
        return schedule.first { now >= $0.startTime && now <= $0.endTime }
    }
    
    private var nextAct: Act? {
        let now = Date()
        return schedule
            .first { $0.startTime > now } // Find first future event
    }
    
    private var progress: Double {
        guard let current = currentAct else { return 0 }
        let now = Date()
        let totalDuration = current.duration
        let elapsed = now.timeIntervalSince(current.startTime)
        return min(max(elapsed / totalDuration, 0), 1)
    }
    
    private var timeUntilNext: TimeInterval? {
        guard let next = nextAct else { return nil }
        return next.startTime.timeIntervalSince(Date())
    }
    
    #if os(macOS)
    private let screenSleep = ScreenSleep()
    #endif
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                // Top bar with settings and current act
                HStack(alignment: .center) {
                    if let act = currentAct {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOW")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            Text(act.name)
                                .font(.system(size: {
                                    #if os(macOS)
                                    return 36
                                    #else
                                    return 46
                                    #endif
                                }()))
                                .fontWeight(.bold)
                        }
                    } else {
                        Text("UP NEXT")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Always reserve space for the button, but control its opacity
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.gray)
                    }
                    .opacity(showControls ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: showControls)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                // Time display
                if currentAct != nil {
                    Text(timeString(from: timeRemaining))
                        .font(.system(size: {
                            #if os(macOS)
                            return min(geometry.size.width, geometry.size.height) * 0.25
                            #else
                            return min(geometry.size.width, geometry.size.height) * 0.3
                            #endif
                        }()))
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(timeRemaining < 300 ? .red : .primary)
                        .opacity(shouldFlash ? (isVisible ? 1 : 0.2) : 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let next = nextAct {
                    VStack(spacing: 12) {
                        if let imageData = next.attachmentImage,
                           let platformImage = {
                               #if os(iOS)
                               return UIImage(data: imageData)
                               #else
                               return NSImage(data: imageData)
                               #endif
                           }() {
                            Group {
                                #if os(iOS)
                                Image(uiImage: platformImage)
                                    .resizable()
                                #else
                                Image(nsImage: platformImage)
                                    .resizable()
                                    .interpolation(.high)
                                #endif
                            }
                            .scaledToFit()
                            .frame(maxHeight: min(geometry.size.width, geometry.size.height) * 0.4)
                        } else {
                            Text(next.name)
                                .font(.system(size: {
                                    #if os(macOS)
                                    return min(geometry.size.width, geometry.size.height) * 0.15
                                    #else
                                    return min(geometry.size.width, geometry.size.height) * 0.2
                                    #endif
                                }()))
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                        }
                        
                        Text("Starts at \(next.startTime, style: .time)")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("No Upcoming Events")
                        .font(.system(size: {
                            #if os(macOS)
                            return min(geometry.size.width, geometry.size.height) * 0.08
                            #else
                            return min(geometry.size.width, geometry.size.height) * 0.1
                            #endif
                        }()))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Next up - only show when there's a current event
                if let _ = currentAct, let next = nextAct {
                    VStack(spacing: 8) {
                        Text("UP NEXT")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        if let imageData = next.attachmentImage,
                           let platformImage = {
                               #if os(iOS)
                               return UIImage(data: imageData)
                               #else
                               return NSImage(data: imageData)
                               #endif
                           }() {
                            Group {
                                #if os(iOS)
                                Image(uiImage: platformImage)
                                    .resizable()
                                #else
                                Image(nsImage: platformImage)
                                    .resizable()
                                    .interpolation(.high)
                                #endif
                            }
                            .scaledToFit()
                            .frame(height: 60)
                        } else {
                            Text(next.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Starts at")
                            Text(next.startTime, style: .time)
                            Text("•")
                            Text("Ends at")
                            Text(next.endTime, style: .time)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical)
                }
            }
            .padding(.top, geometry.safeAreaInsets.top + 20)
            .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
            .padding(.horizontal, geometry.safeAreaInsets.leading)
            #if os(macOS)
            .frame(minWidth: 800, minHeight: 600)
            .background(Color.black)  // Force black background in dark mode
            #endif
        }
        .edgesIgnoringSafeArea(.all)
        #if os(macOS)
        .preferredColorScheme(.dark)  // Force dark mode on macOS
        #endif
        .sheet(isPresented: $showingSettings) {
            TimerSettingsView(
                initialTime: $initialTime,
                timeRemaining: $timeRemaining,
                isRunning: $isRunning,
                schedule: $schedule,
                calendarManager: calendarManager
            )
        }
        .onReceive(timer) { _ in
            if isRunning && timeRemaining > 0 {
                timeRemaining -= 1
            }
        }
        .onReceive(flashTimer) { _ in
            if shouldFlash {
                isVisible.toggle()
            } else {
                isVisible = true
            }
        }
        .onReceive(scheduleTimer) { _ in
            updateFromSchedule()
        }
        .contentShape(Rectangle()) // Make entire view tappable
        .onTapGesture {
            lastTouchTime = Date()
            showControls = true
        }
        .onReceive(controlTimer) { _ in
            if Date().timeIntervalSince(lastTouchTime) > controlTimeout {
                showControls = false
            }
        }
        .onAppear {
            #if os(macOS)
            preventScreenSleep()
            #else
            UIApplication.shared.isIdleTimerDisabled = true
            #endif
            
            calendarManager.startMonitoring { newSchedule in
                schedule = newSchedule
            }
        }
        .onDisappear {
            #if os(macOS)
            allowScreenSleep()
            #else
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
    }
    
    #if os(macOS)
    private func preventScreenSleep() {
        screenSleep.prevent()
    }
    
    private func allowScreenSleep() {
        screenSleep.allow()
    }
    #endif
    
    private func updateFromSchedule() {
        guard let current = currentAct else {
            isRunning = false
            return
        }
        
        let now = Date()
        let remaining = current.endTime.timeIntervalSince(now)
        
        timeRemaining = max(0, remaining)
        initialTime = current.duration
        
        if now >= current.startTime && now <= current.endTime {
            isRunning = true
        }
    }
    
    private var shouldFlash: Bool {
        timeRemaining <= 60 && timeRemaining > 0 && isRunning
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func resetTimer() {
        timeRemaining = initialTime
        isRunning = false
    }
}

struct TimerSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var initialTime: TimeInterval
    @Binding var timeRemaining: TimeInterval
    @Binding var isRunning: Bool
    @Binding var schedule: [Act]
    @State private var hours: Int = 0
    @State private var minutes: Int = 45
    @State private var showingScheduleEditor = false
    @ObservedObject var calendarManager: CalendarManager
    @State private var calendarSyncEnabled: Bool
    @State private var showingMailView = false
    @State private var showingMailError = false
    
    init(initialTime: Binding<TimeInterval>,
         timeRemaining: Binding<TimeInterval>,
         isRunning: Binding<Bool>,
         schedule: Binding<[Act]>,
         calendarManager: CalendarManager) {
        self._initialTime = initialTime
        self._timeRemaining = timeRemaining
        self._isRunning = isRunning
        self._schedule = schedule
        self.calendarManager = calendarManager
        self._calendarSyncEnabled = State(initialValue: calendarManager.isEnabled)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Calendar Integration") {
                    Toggle("Sync with Calendar", isOn: $calendarSyncEnabled)
                        .onChange(of: calendarSyncEnabled) { oldValue, newValue in
                            calendarManager.toggleSync(enabled: newValue) { newSchedule in
                                schedule = newSchedule
                            }
                        }
                    
                    if !calendarManager.hasCalendarAccess {
                        Text("Please grant calendar access in Settings to sync with your calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if calendarSyncEnabled {
                    Section {
                        Button("Custom Schedule") {
                            showingScheduleEditor = true
                        }
                        .disabled(calendarSyncEnabled) // Disable manual editing when sync is on
                    }
                } else {
                    Section {
                        Button("Custom Schedule") {
                            showingScheduleEditor = true
                        }
                    }
                }
                
                Section("Manual") {
                    NavigationLink("Controls") {
                        ManualDetailView(
                            title: "Controls",
                            description: "The large center area is your main control surface.",
                            items: [
                                "Tap anywhere on screen to show/hide controls",
                                "Controls will automatically hide after 5 seconds",
                                "Settings can be accessed via the gear icon",
                                "Double tap to reset the timer"
                            ]
                        )
                    }
                    
                    NavigationLink("Calendar Integration") {
                        ManualDetailView(
                            title: "Calendar Integration",
                            description: "Sync your schedule with your calendar.",
                            items: [
                                "Enable calendar sync to automatically load your schedule",
                                "Events will automatically start at their scheduled time",
                                "Calendar sync must be enabled in device settings",
                                "Events can include images from calendar attachments"
                            ]
                        )
                    }
                    
                    NavigationLink("Custom Schedule") {
                        ManualDetailView(
                            title: "Custom Schedule",
                            description: "Create and manage your own event schedule.",
                            items: [
                                "Add events with custom names and times",
                                "Set precise durations for each event",
                                "Drag to reorder your schedule",
                                "Use 'Start Now' for immediate timing"
                            ]
                        )
                    }
                    
                    NavigationLink("Timer Behavior") {
                        ManualDetailView(
                            title: "Timer Behavior",
                            description: "Understanding how the timer works.",
                            items: [
                                "Timer shows remaining time for current event",
                                "Display turns red under 5 minutes",
                                "Timer flashes in the final minute",
                                "Screen stays active during operation"
                            ]
                        )
                    }
                }
                
                Section {
                    Button(action: {
                        let email = "support@lumonlabs.io"
                        if let url = URL(string: "mailto:\(email)") {
                            if UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url)
                            } else {
                                showingMailError = true
                            }
                        }
                    }) {
                        HStack {
                            Text("Contact Support")
                            Spacer()
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .alert("Cannot Open Mail", isPresented: $showingMailError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Please make sure you have an email client configured on your device.")
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingScheduleEditor) {
                ScheduleEditorView(
                    schedule: $schedule,
                    timeRemaining: $timeRemaining,
                    initialTime: $initialTime,
                    isRunning: $isRunning
                )
            }
            #if os(macOS)
            .frame(minWidth: 500, idealWidth: 600, maxWidth: .infinity)
            .frame(minHeight: 400, idealHeight: 500, maxHeight: .infinity)
            .padding()
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 400)
        .background(Color.black)
        #endif
    }
}

struct ScheduleEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var schedule: [Act]
    @Binding var timeRemaining: TimeInterval
    @Binding var initialTime: TimeInterval
    @Binding var isRunning: Bool
    @State private var newActName = ""
    @State private var newActStartTime = Date()
    @State private var newActEndTime = Date().addingTimeInterval(45 * 60)
    @State private var durationDate = Calendar.current.date(bySettingHour: 0, minute: 45, second: 0, of: Date()) ?? Date()
    
    private var newActDuration: TimeInterval {
        let components = Calendar.current.dateComponents([.hour, .minute], from: durationDate)
        return TimeInterval((components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Add New Event") {
                    TextField("Event Name", text: $newActName)
                    
                    DatePicker("Start Time", 
                             selection: $newActStartTime,
                             displayedComponents: [.hourAndMinute])
                        .onChange(of: newActStartTime) { oldValue, newValue in
                            newActEndTime = newValue.addingTimeInterval(newActDuration)
                        }
                    
                    DatePicker("End Time", 
                             selection: $newActEndTime,
                             displayedComponents: [.hourAndMinute])
                        .onChange(of: newActEndTime) { _, newValue in
                            let duration = newValue.timeIntervalSince(newActStartTime)
                            updateDurationDate(from: duration)
                        }
                    
                    DatePicker("Duration",
                             selection: $durationDate,
                             displayedComponents: [.hourAndMinute])
                        .onChange(of: durationDate) { _, _ in
                            newActEndTime = newActStartTime.addingTimeInterval(newActDuration)
                        }
                    
                    Button("Add Event") {
                        let act = Act(
                            name: newActName,
                            duration: newActDuration,
                            startTime: newActStartTime
                        )
                        schedule.append(act)
                        schedule.sort { $0.startTime < $1.startTime }
                        resetForm()
                    }
                    .disabled(newActName.isEmpty || newActDuration <= 0)
                }
                
                if !schedule.isEmpty {
                    Section("Schedule") {
                        ForEach(schedule) { act in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(act.name)
                                        .font(.headline)
                                    HStack {
                                        Text(act.startTime, style: .time)
                                        Text("-")
                                        Text(act.endTime, style: .time)
                                        Text("•")
                                        Text(formatDuration(act.duration))
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Button("Start Now") {
                                    let now = Date()
                                    if schedule.firstIndex(where: { $0.id == act.id }) != nil {
                                        // First create the updated act
                                        let updatedAct = Act(
                                            name: act.name,
                                            duration: act.duration,
                                            startTime: now
                                        )
                                        
                                        // Create a new array without the current events
                                        var updatedSchedule = schedule.filter { event in
                                            !(now >= event.startTime && now <= event.endTime)
                                        }
                                        
                                        // Add the new act
                                        updatedSchedule.append(updatedAct)
                                        
                                        // Sort and update the schedule
                                        updatedSchedule.sort { $0.startTime < $1.startTime }
                                        schedule = updatedSchedule
                                        
                                        // Update timer state
                                        initialTime = updatedAct.duration
                                        timeRemaining = updatedAct.duration
                                        isRunning = true
                                        
                                        // Removed the dismiss() call
                                    }
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.blue)
                                
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { indexSet in
                            schedule.remove(atOffsets: indexSet)
                        }
                        .onMove { from, to in
                            // First move the item
                            schedule.move(fromOffsets: from, toOffset: to)
                            
                            // Then update all event times to maintain sequence
                            var updatedSchedule = [Act]()
                            var currentTime = schedule[0].startTime
                            
                            for act in schedule {
                                let updatedAct = Act(
                                    name: act.name,
                                    duration: act.duration,
                                    startTime: currentTime
                                )
                                updatedSchedule.append(updatedAct)
                                currentTime = updatedAct.endTime.addingTimeInterval(300) // 5 minute gap
                            }
                            
                            schedule = updatedSchedule
                        }
                    }
                }
            }
            .navigationTitle("Schedule")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #if os(macOS)
            .frame(minWidth: 500, idealWidth: 600, maxWidth: .infinity)
            .frame(minHeight: 500, idealHeight: 600, maxHeight: .infinity)
            .padding()
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 500)
        .background(Color.black)
        #endif
    }
    
    private func updateDurationDate(from duration: TimeInterval) {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        durationDate = Calendar.current.date(bySettingHour: hours, minute: minutes, second: 0, of: Date()) ?? durationDate
    }
    
    private func resetForm() {
        newActName = ""
        newActStartTime = Date()
        durationDate = Calendar.current.date(bySettingHour: 0, minute: 45, second: 0, of: Date()) ?? Date()
        newActEndTime = newActStartTime.addingTimeInterval(newActDuration)
    }
    
    private func formatDuration(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct ManualDetailView: View {
    let title: String
    let description: String
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 4)
            
            Text(description)
                .font(.title3)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(item)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            Spacer()
        }
        .padding(24)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(.headline)
            }
        }
    }
}

#Preview {
    ContentView()
}
