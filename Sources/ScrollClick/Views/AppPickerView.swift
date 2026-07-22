import SwiftUI

public struct AppPickerView: View {
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var appDetector = AppDetector.shared
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Select Target Application")
                        .font(.headline)
                    Text("Choose an active app or enter custom process name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search running apps...", text: $appDetector.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Running Apps List
            List {
                Section(header: Text("Minecraft Presets")) {
                    Button(action: {
                        settings.targetAppName = "Minecraft"
                        settings.targetAppBundleId = ""
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "cube.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("Minecraft / Java (General)")
                                    .fontWeight(.medium)
                                Text("Matches Minecraft, java, LWJGL")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if settings.targetAppName == "Minecraft" {
                                Image(systemName: "checkmark").foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        settings.targetAppName = "java"
                        settings.targetAppBundleId = ""
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "cup.and.saucer.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text("Java Runtime Executable")
                                    .fontWeight(.medium)
                                Text("Process name: java")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if settings.targetAppName == "java" {
                                Image(systemName: "checkmark").foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Section(header: Text("Currently Running Applications")) {
                    let filtered = appDetector.runningApps.filter {
                        appDetector.searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(appDetector.searchText)
                    }
                    
                    if filtered.isEmpty {
                        Text("No matching running applications found")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(filtered) { app in
                            Button(action: {
                                settings.targetAppName = app.name
                                settings.targetAppBundleId = app.bundleIdentifier ?? ""
                                dismiss()
                            }) {
                                HStack(spacing: 12) {
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                    } else {
                                        Image(systemName: "app.fill")
                                            .frame(width: 24, height: 24)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.name)
                                            .fontWeight(.medium)
                                        if let bundleId = app.bundleIdentifier {
                                            Text(bundleId)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if settings.targetAppName == app.name {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minHeight: 250)
            
            // Custom Name Input
            VStack(alignment: .leading, spacing: 6) {
                Text("Or enter exact Process/Window Name:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    TextField("e.g. java, Lunar Client, org.lwjgl.glfw", text: $settings.targetAppName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
        }
        .padding(20)
        .frame(width: 450, height: 480)
        .onAppear {
            appDetector.refreshRunningApps()
        }
    }
}
