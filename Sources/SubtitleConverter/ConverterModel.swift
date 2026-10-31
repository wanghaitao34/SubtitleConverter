import AppKit
import SwiftUI
import SubtitleCore
import UniformTypeIdentifiers

@MainActor
final class ConverterModel: ObservableObject {
    @Published private(set) var files: [ImportedSubtitle] = []
    @Published var selection: Set<URL> = []
    @Published private(set) var isBusy = false
    @Published private(set) var status = "离线处理 · 字幕不会上传"
    @Published var format: ExportFormat = .webVTT
    @Published var errorMessage = ""
    @Published var showsError = false
    @Published var isDropTarget = false
    @Published private(set) var outputDirectory: URL?

    var selectedFiles: [ImportedSubtitle] { files.filter { selection.contains($0.id) } }

    func chooseFile() { chooseImport(folder: false) }
    func chooseFolder() { chooseImport(folder: true) }

    private func chooseImport(folder: Bool) {
        guard !isBusy else { return }
        let panel = NSOpenPanel()
        panel.title = folder ? "导入文件夹（包括子文件夹）" : "导入 SRT 字幕"
        panel.prompt = "导入"
        panel.canChooseFiles = !folder
        panel.canChooseDirectories = folder
        panel.allowsMultipleSelection = true
        if !folder { panel.allowedContentTypes = [UTType(filenameExtension: "srt") ?? .plainText] }
        if panel.runModal() == .OK { load(panel.urls) }
    }

    func load(_ url: URL) { load([url]) }

    func load(_ urls: [URL], additionalErrors: [String] = []) {
        guard !isBusy else { return }
        isBusy = true
        status = "正在扫描并检查字幕…"
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                SubtitleBatch.importFiles(urls)
            }.value
            var existing = Set(files.map(\.id))
            var added = 0
            for file in result.files {
                if existing.insert(file.id).inserted {
                    files.append(file)
                    added += 1
                } else if let index = files.firstIndex(where: { $0.id == file.id }) {
                    files[index] = file
                }
                selection.insert(file.id)
            }
            status = "新增 \(added) 个文件 · \(files.count) 个有效字幕 · \(result.issues.count + additionalErrors.count) 个问题"
            if !result.issues.isEmpty || !additionalErrors.isEmpty {
                presentIssues(result.issues, title: "部分文件无法导入", additionalErrors: additionalErrors)
            }
            isBusy = false
        }
    }

    func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !isBusy, !providers.isEmpty else { return false }
        isBusy = true
        status = "正在读取拖入的文件…"
        Task {
            var urls: [URL] = []
            var failures: [String] = []
            for provider in providers {
                do {
                    let url: URL = try await withCheckedThrowingContinuation { continuation in
                        provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
                            if let error { continuation.resume(throwing: error) }
                            else if let data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                                continuation.resume(returning: url)
                            } else {
                                continuation.resume(throwing: SubtitleError.invalidContent("拖入的文件地址无效。"))
                            }
                        }
                    }
                    urls.append(url)
                } catch {
                    failures.append(error.localizedDescription)
                }
            }
            isBusy = false
            if !urls.isEmpty {
                load(urls, additionalErrors: failures)
            } else {
                errorMessage = "部分拖入项目无法读取：\n" + failures.joined(separator: "\n")
                showsError = true
                status = "未能读取拖入的文件。"
            }
        }
        return true
    }

    func selectAll() { selection = Set(files.map(\.id)) }
    func deselectAll() { selection.removeAll() }
    func clear() {
        files.removeAll()
        selection.removeAll()
        status = "列表已清空，原始文件未修改。"
    }

    func exportFile() {
        let chosen = selectedFiles
        guard !chosen.isEmpty, !isBusy else { return }
        let panel = NSOpenPanel()
        panel.title = "选择批量导出目录"
        panel.prompt = "导出到此文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = outputDirectory
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        outputDirectory = directory
        let selectedFormat = format
        isBusy = true
        status = "正在导出 \(chosen.count) 个文件…"
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                SubtitleBatch.exportFiles(chosen, format: selectedFormat, directory: directory)
            }.value
            status = "导出完成：成功 \(result.destinations.count) 个，失败 \(result.issues.count) 个 · \(directory.lastPathComponent)"
            if !result.issues.isEmpty { presentIssues(result.issues, title: "部分文件导出失败") }
            isBusy = false
        }
    }

    func revealOutput() {
        if let outputDirectory { NSWorkspace.shared.open(outputDirectory) }
    }

    private func presentIssues(_ issues: [BatchIssue], title: String, additionalErrors: [String] = []) {
        errorMessage = title + "（\(issues.count + additionalErrors.count) 个）：\n\n"
            + (issues.map { "\($0.url.path)\n\($0.message)" } + additionalErrors).joined(separator: "\n\n")
        showsError = true
    }
}
