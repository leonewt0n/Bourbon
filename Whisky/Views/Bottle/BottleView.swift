//
//  BottleView.swift
//  Whisky
//
//  This file is part of Whisky.
//
//  Whisky is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Whisky is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Whisky.
//  If not, see https://www.gnu.org/licenses/.
//

import SwiftUI
import UniformTypeIdentifiers
import WhiskyKit

enum BottleStage {
    case config
    case programs
    case processes
}

struct BottleView: View {
    @ObservedObject var bottle: Bottle
    @State private var path = NavigationPath()
    @State private var programLoading: Bool = false
    @State private var showWinetricksSheet: Bool = false
    @State private var runtimeAIOLoading: Bool = false
    @State private var showRuntimeAIOAlert: Bool = false
    @State private var runtimeAIOAlertMessage: String = ""

    private let gridLayout = [GridItem(.adaptive(minimum: 100, maximum: .infinity))]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVGrid(columns: gridLayout, alignment: .center) {
                    ForEach(bottle.pinnedPrograms, id: \.id) { pinnedProgram in
                        PinView(
                            bottle: bottle, program: pinnedProgram.program, pin: pinnedProgram.pin, path: $path
                        )
                    }
                    PinAddView(bottle: bottle)
                }
                .padding()
                Form {
                    NavigationLink(value: BottleStage.programs) {
                        Label("tab.programs", systemImage: "list.bullet")
                    }
                    NavigationLink(value: BottleStage.config) {
                        Label("tab.config", systemImage: "gearshape")
                    }
//                    NavigationLink(value: BottleStage.processes) {
//                        Label("tab.processes", systemImage: "hockey.puck.circle")
//                    }
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
            }
            .bottomBar {
                HStack {
                    Button("RuntimeAIO") {
                        Task {
                            await installRuntimeAIO()
                        }
                    }
                    .disabled(runtimeAIOLoading)
                    if runtimeAIOLoading {
                        Spacer()
                            .frame(width: 10)
                        ProgressView()
                            .controlSize(.small)
                    }
                    Spacer()
                    Button("kill.bottles") {
                        WhiskyApp.killBottles()
                    }
                    Button("button.cDrive") {
                        bottle.openCDrive()
                    }
                    Button("winecfg") {
                        bottle.openWinecfg()
                    }
                    Button("button.winetricks") {
                        showWinetricksSheet.toggle()
                    }
                    Button("button.run") {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        panel.canChooseFiles = true
                        panel.allowedContentTypes = [UTType.exe,
                                                     UTType(exportedAs: "com.microsoft.msi-installer"),
                                                     UTType(exportedAs: "com.microsoft.bat")]
                        panel.directoryURL = bottle.url.appending(path: "drive_c")
                        panel.begin { result in
                            programLoading = true
                            Task(priority: .userInitiated) {
                                if result == .OK {
                                    if let url = panel.urls.first {
                                        do {
                                            if url.pathExtension == "bat" {
                                                try await Wine.runBatchFile(url: url, bottle: bottle)
                                            } else {
                                                try await Wine.runProgram(at: url, bottle: bottle)
                                            }
                                        } catch {
                                            print("Failed to run external program: \(error)")
                                        }
                                        programLoading = false
                                    }
                                } else {
                                    programLoading = false
                                }
                                updateStartMenu()
                            }
                        }
                    }
                    .disabled(programLoading)
                    if programLoading {
                        Spacer()
                            .frame(width: 10)
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding()
            }
            .onAppear {
                updateStartMenu()
            }
            .disabled(!bottle.isAvailable)
            .navigationTitle(bottle.settings.name)
            .sheet(isPresented: $showWinetricksSheet) {
                WinetricksView(bottle: bottle)
            }
            .alert("RuntimeAIO", isPresented: $showRuntimeAIOAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(runtimeAIOAlertMessage)
            }
            .onChange(of: bottle.settings) { oldValue, newValue in
                guard oldValue != newValue else { return }
                // Trigger a reload
                BottleVM.shared.bottles = BottleVM.shared.bottles
            }
            .navigationDestination(for: BottleStage.self) { stage in
                switch stage {
                case .config:
                    ConfigView(bottle: bottle)
                case .programs:
                    ProgramsView(
                        bottle: bottle, path: $path
                    )
                case .processes:
                    RunningProcessesView(bottle: bottle)
                }
            }
            .navigationDestination(for: Program.self) { program in
                ProgramView(program: program)
            }
        }
    }

    private func updateStartMenu() {
        bottle.updateInstalledPrograms()

        let startMenuPrograms = bottle.getStartMenuPrograms()
        for startMenuProgram in startMenuPrograms {
            for program in bottle.programs where
            // For some godforsaken reason "foo/bar" != "foo/Bar" so...
            program.url.path().caseInsensitiveCompare(startMenuProgram.url.path()) == .orderedSame {
                program.pinned = true
                guard !bottle.settings.pins.contains(where: { $0.url == program.url }) else { return }
                bottle.settings.pins.append(PinnedProgram(
                    name: program.url.deletingPathExtension().lastPathComponent,
                    url: program.url
                ))
            }
        }
    }
    @MainActor
    private func installRuntimeAIO() async {
        runtimeAIOLoading = true
        defer { runtimeAIOLoading = false }
        do {
            // Download the archive
            let urlString = "https://github.com/leonewt0n/Bourbon/raw/refs/heads/main/RuntimeAIO.tar.gz"
            guard let url = URL(string: urlString) else {
                throw RuntimeAIOError.invalidURL
            }
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            // Create temporary directory for extraction
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer {
                try? FileManager.default.removeItem(at: tempDir)
            }
            // Extract the tar.gz file
            let extractProcess = Process()
            extractProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            extractProcess.arguments = ["-xzf", tempURL.path, "-C", tempDir.path]
            try extractProcess.run()
            extractProcess.waitUntilExit()
            guard extractProcess.terminationStatus == 0 else {
                throw RuntimeAIOError.extractionFailed
            }
            // Find install_all.bat file
            let installScript = tempDir.appendingPathComponent("install_all.bat")
            guard FileManager.default.fileExists(atPath: installScript.path) else {
                // Try to find it recursively in subdirectories
                if let foundScript = try findInstallScript(in: tempDir) {
                    try await Wine.runBatchFile(url: foundScript, bottle: bottle)
                } else {
                    throw RuntimeAIOError.installScriptNotFound
                }
                return
            }
            // Run the install_all.bat file
            try await Wine.runBatchFile(url: installScript, bottle: bottle)
            runtimeAIOAlertMessage = "RuntimeAIO installation completed successfully!"
            showRuntimeAIOAlert = true
        } catch {
            runtimeAIOAlertMessage = "RuntimeAIO installation failed: \(error.localizedDescription)"
            showRuntimeAIOAlert = true
        }
    }
    private func findInstallScript(in directory: URL) throws -> URL? {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.lastPathComponent.lowercased() == "install_all.bat" {
                return fileURL
            }
        }
        return nil
    }
}

enum RuntimeAIOError: LocalizedError {
    case invalidURL
    case extractionFailed
    case installScriptNotFound
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid download URL"
        case .extractionFailed:
            return "Failed to extract archive"
        case .installScriptNotFound:
            return "install_all.bat not found in archive"
        }
    }
}
