import Foundation

public struct ImportedSubtitle: Identifiable, Sendable {
    public let url: URL
    public let document: SubtitleDocument
    public var id: URL { url }
}

public struct BatchIssue: Sendable {
    public let url: URL
    public let message: String
}

public struct ImportResult: Sendable {
    public var files: [ImportedSubtitle] = []
    public var issues: [BatchIssue] = []
}

public struct ExportResult: Sendable {
    public var destinations: [URL] = []
    public var issues: [BatchIssue] = []
}

public enum SubtitleBatch {
    /// Directory imports skip hidden files, packages and symlinks to avoid cycles or escaping the chosen tree.
    public static func scan(_ inputs: [URL]) -> (files: [URL], issues: [BatchIssue]) {
        let manager = FileManager.default
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
        var files = Set<URL>()
        var issues: [BatchIssue] = []
        for input in inputs {
            do {
                guard input.isFileURL else {
                    throw SubtitleError.invalidContent("仅支持本地文件或文件夹。")
                }
                let values = try input.resourceValues(forKeys: keys)
                if values.isDirectory == true {
                    guard let enumerator = manager.enumerator(
                        at: input, includingPropertiesForKeys: Array(keys),
                        options: [.skipsHiddenFiles, .skipsPackageDescendants],
                        errorHandler: { url, error in
                            issues.append(BatchIssue(url: url, message: error.localizedDescription))
                            return true
                        }
                    ) else {
                        throw SubtitleError.invalidContent("无法读取文件夹。")
                    }
                    for case let url as URL in enumerator {
                        do {
                            let entry = try url.resourceValues(forKeys: keys)
                            if entry.isSymbolicLink == true {
                                enumerator.skipDescendants()
                                continue
                            }
                            if entry.isRegularFile == true, url.pathExtension.lowercased() == "srt" {
                                files.insert(url.standardizedFileURL.resolvingSymlinksInPath())
                            }
                        } catch {
                            issues.append(BatchIssue(url: url, message: error.localizedDescription))
                        }
                    }
                } else if values.isRegularFile == true, input.pathExtension.lowercased() == "srt" {
                    files.insert(input.standardizedFileURL.resolvingSymlinksInPath())
                } else {
                    throw SubtitleError.invalidContent("请选择 .srt 文件或文件夹。")
                }
            } catch {
                issues.append(BatchIssue(url: input, message: error.localizedDescription))
            }
        }
        return (files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }, issues)
    }

    public static func importFiles(_ inputs: [URL]) -> ImportResult {
        let access = inputs.filter { $0.startAccessingSecurityScopedResource() }
        defer { access.forEach { $0.stopAccessingSecurityScopedResource() } }
        let scanned = scan(inputs)
        var result = ImportResult()
        result.issues = scanned.issues
        for url in scanned.files {
            do {
                result.files.append(ImportedSubtitle(
                    url: url, document: try SubtitleDocument.parse(data: Data(contentsOf: url))
                ))
            } catch {
                result.issues.append(BatchIssue(url: url, message: error.localizedDescription))
            }
        }
        if scanned.files.isEmpty, result.issues.isEmpty {
            result.issues.append(BatchIssue(
                url: inputs.first ?? URL(fileURLWithPath: "/"),
                message: "所选文件夹中没有找到 SRT 字幕（已扫描子文件夹）。"
            ))
        }
        return result
    }

    public static func exportFiles(
        _ files: [ImportedSubtitle], format: ExportFormat, directory: URL
    ) -> ExportResult {
        var result = ExportResult()
        let access = directory.startAccessingSecurityScopedResource()
        defer { if access { directory.stopAccessingSecurityScopedResource() } }
        for file in files {
            do {
                let destination = availableDestination(source: file.url, format: format, directory: directory)
                // Exclusive creation also prevents a concurrent writer from being silently overwritten.
                try file.document.export(format).write(to: destination, options: .withoutOverwriting)
                result.destinations.append(destination)
            } catch {
                result.issues.append(BatchIssue(url: file.url, message: error.localizedDescription))
            }
        }
        return result
    }

    public static func availableDestination(source: URL, format: ExportFormat, directory: URL) -> URL {
        let base = source.deletingPathExtension().lastPathComponent
            + (format == .windowsSRT ? "-windows" : "")
        var number = 1
        let canonicalSource = source.standardizedFileURL.resolvingSymlinksInPath()
        while true {
            let suffix = number == 1 ? "" : " (\(number))"
            let candidate = directory.appendingPathComponent(base + suffix + "." + format.fileExtension)
            if candidate.standardizedFileURL.resolvingSymlinksInPath() != canonicalSource,
               !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            number += 1
        }
    }
}
