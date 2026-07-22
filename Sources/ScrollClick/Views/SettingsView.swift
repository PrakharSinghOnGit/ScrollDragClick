import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var accessibility = AccessibilityManager.shared
    @ObservedObject var appDetector = AppDetector.shared
    @ObservedObject var engine = ScrollTapEngine.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Banner
                headerView
                
                // Accessibility Permission Warning if needed
                if !accessibility.isTrusted {
                    accessibilityWarningView
                }
                
                // 1. Target App Configuration
                targetAppSection
                
                // 2. Click Ratio / Count Configuration
                clickRatioSection
                
                // 3. Scroll Direction Configuration
                scrollDirectionSection
                
                // 4. Mouse Button Selection
                mouseButtonSection
                
                // 5. Scroll Behavior & Options
                scrollBehaviorSection
                
                // 6. Interactive Test Box & Live Stats
                testAreaSection
            }
            .padding(22)
        }
        .frame(minWidth: 520, minHeight: 620)
        .sheet(isPresented: $settings.isShowingAppPicker) {
            AppPickerView()
        }
    }
    
    // MARK: - Header
    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(settings.isEnabled ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 26))
                    .foregroundColor(settings.isEnabled ? .green : .secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("ScrollClick")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("v1.0")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Text("Minecraft Drag-Click & Scroll-to-Mouse Trigger")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle(settings.isEnabled ? "Active" : "Disabled", isOn: $settings.isEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .font(.headline)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Accessibility Warning
    @ViewBuilder
    private var accessibilityWarningView: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility Permission Required")
                    .fontWeight(.semibold)
                Text("macOS requires Accessibility access to listen to scroll events and send mouse clicks.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Grant Access") {
                accessibility.promptPermission()
                accessibility.openAccessibilitySettings()
            }
            .buttonStyle(BorderedProminentButtonStyle())
            .tint(.orange)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 1))
        .cornerRadius(10)
    }
    
    // MARK: - 1. Target App
    @ViewBuilder
    private var targetAppSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("1. Target Application Filter", systemImage: "app.dashed")
                .font(.headline)
            
            Picker("Active Mode:", selection: $settings.targetAppMode) {
                ForEach(TargetAppMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            if settings.targetAppMode == .specific {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Selected Target:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Image(systemName: "cube.fill")
                                .foregroundColor(.green)
                            Text(settings.targetAppName.isEmpty ? "None Selected" : settings.targetAppName)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Choose App...") {
                        settings.isShowingAppPicker = true
                    }
                }
                .padding(10)
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(8)
                
                HStack(spacing: 4) {
                    Text("Currently Frontmost:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(appDetector.frontmostAppName)
                        .font(.caption)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    if appDetector.isTargetAppActive(settings: settings) {
                        Text("MATCHED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    } else {
                        Text("NOT MATCHED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - 2. Click Ratio / Count
    @ViewBuilder
    private var clickRatioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("2. Scroll Click Count & Ratio", systemImage: "slider.horizontal.3")
                .font(.headline)
            
            Picker("Ratio Mode:", selection: $settings.ratioMode) {
                ForEach(RatioMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            if settings.ratioMode == .clicksPerScroll {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Clicks per 1 Scroll Tick:")
                        Spacer()
                        Text("\(settings.clicksPerScroll) click(s)")
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                    }
                    Stepper("", value: $settings.clicksPerScroll, in: 1...20)
                        .labelsHidden()
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Scroll Ticks per 1 Click:")
                        Spacer()
                        Text("\(settings.scrollsPerClick) scroll(s)")
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                    }
                    Stepper("", value: $settings.scrollsPerClick, in: 1...10)
                        .labelsHidden()
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Multi-Click Delay:")
                    Spacer()
                    Text("\(settings.clickDelayMs) ms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(settings.clickDelayMs) },
                    set: { settings.clickDelayMs = Int($0) }
                ), in: 0...50, step: 1)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - 3. Scroll Direction
    @ViewBuilder
    private var scrollDirectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("3. Scroll Direction Filter", systemImage: "arrow.up.and.down")
                .font(.headline)
            
            Picker("Direction:", selection: $settings.scrollDirection) {
                ForEach(ScrollDirectionOption.allCases) { dir in
                    Text(dir.rawValue).tag(dir)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - 4. Mouse Button Selection
    @ViewBuilder
    private var mouseButtonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("4. Mouse Button Target", systemImage: "hand.tap.fill")
                .font(.headline)
            
            Picker("Mouse Button:", selection: $settings.mouseButton) {
                ForEach(MouseButtonOption.allCases) { button in
                    Text(button.rawValue).tag(button)
                }
            }
            .pickerStyle(PopUpButtonPickerStyle())
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - 5. Scroll Behavior
    @ViewBuilder
    private var scrollBehaviorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("5. Scroll Wheel Behavior", systemImage: "gearshape")
                .font(.headline)
            
            Toggle(isOn: $settings.suppressOriginalScroll) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suppress Original Scroll Wheel Event")
                        .fontWeight(.medium)
                    Text("Prevents Minecraft from changing hotbar item slots while scroll clicking.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - 6. Interactive Test Box
    @ViewBuilder
    private var testAreaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Live Click Tester & Stats", systemImage: "gauge.with.needle")
                    .font(.headline)
                Spacer()
                Button("Reset Stats") {
                    engine.totalClicksGenerated = 0
                    settings.testClickCount = 0
                }
                .font(.caption)
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Total Clicks Generated:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(engine.totalClicksGenerated)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Divider().frame(height: 36)
                
                VStack(alignment: .leading) {
                    Text("Test Box Clicks Received:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(settings.testClickCount)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                }
            }
            
            // Interactive test pad
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(height: 70)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                    )
                
                Text("Hover & Scroll here to test scroll-to-click!")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
            }
            .onTapGesture {
                settings.testClickCount += 1
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}
