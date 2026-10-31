import AppKit
import SwiftUI

@main
struct SubtitleConverterApp: App {
    @StateObject private var model = ConverterModel()

    init() {
        _model = StateObject(wrappedValue: ConverterModel())
        let arguments = CommandLine.arguments
        guard let option = arguments.firstIndex(of: "--render-preview"),
              arguments.indices.contains(option + 1) else { return }
        let destination = URL(fileURLWithPath: arguments[option + 1])
        let source = arguments.indices.contains(option + 2)
            ? URL(fileURLWithPath: arguments[option + 2])
            : URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Examples/sample.srt")
        let isDark = arguments.contains("--dark")
        DispatchQueue.main.async {
            Task { @MainActor in
                let previewModel = ConverterModel()
                previewModel.load(source)
                while previewModel.isBusy {
                    try? await Task.sleep(for: .milliseconds(20))
                }
                let content = ContentView(model: previewModel)
                    .frame(width: 1100, height: 820)
                    .environment(\.colorScheme, isDark ? .dark : .light)
                let hostingView = NSHostingView(rootView: content)
                hostingView.frame = NSRect(x: 0, y: 0, width: 1100, height: 820)
                hostingView.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
                hostingView.layoutSubtreeIfNeeded()
                hostingView.display()
                guard let bitmap = NSBitmapImageRep(
                    bitmapDataPlanes: nil, pixelsWide: 2200, pixelsHigh: 1640,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
                ) else {
                    fputs("Unable to allocate preview bitmap.\n", stderr)
                    NSApp.terminate(nil)
                    return
                }
                bitmap.size = hostingView.bounds.size
                hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else {
                    fputs("Unable to encode preview PNG.\n", stderr)
                    NSApp.terminate(nil)
                    return
                }
                do {
                    try png.write(to: destination, options: .atomic)
                    print("Preview saved: \(destination.path)")
                } catch {
                    fputs("Unable to save preview PNG: \(error.localizedDescription)\n", stderr)
                }
                NSApp.terminate(nil)
            }
        }
    }

    var body: some Scene {
        WindowGroup("字幕转换工具") {
            ContentView(model: model)
                .frame(minWidth: 940, minHeight: 740)
                .onOpenURL(perform: model.load)
        }
        .defaultSize(width: 1100, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("导入 SRT…", action: model.chooseFile)
                    .keyboardShortcut("o")
                    .disabled(model.isBusy)
                Button("导入文件夹…", action: model.chooseFolder)
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                    .disabled(model.isBusy)
                Button("导出字幕…", action: model.exportFile)
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(model.selection.isEmpty || model.isBusy)
            }
        }
    }
}
