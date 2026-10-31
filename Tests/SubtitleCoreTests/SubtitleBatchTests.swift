import Foundation
import Testing
@testable import SubtitleCore

struct SubtitleBatchTests {
    private let subtitle = "1\n00:00:00,000 --> 00:00:01,000\n你好，批量字幕 🌏\n"

    private func withDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubtitleBatchTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer {
            do { try FileManager.default.removeItem(at: directory) }
            catch { Issue.record("Cannot clean test directory: \(error)") }
        }
        try body(directory)
    }

    private func write(_ relativePath: String, in directory: URL, text: String? = nil) throws -> URL {
        let url = directory.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data((text ?? subtitle).utf8).write(to: url)
        return url
    }

    @Test func scanRecursesFiltersAndDeduplicatesOverlappingInputs() throws {
        try withDirectory { directory in
            let first = try write("a.srt", in: directory)
            let second = try write("nested/deeper/B.SRT", in: directory)
            _ = try write("notes.txt", in: directory)
            _ = try write(".hidden/secret.srt", in: directory)
            _ = try write(".hidden.srt", in: directory)
            let scanned = SubtitleBatch.scan([directory, first, second, directory.appendingPathComponent("nested")])
            #expect(scanned.files == [first, second])
            #expect(scanned.issues.isEmpty)
        }
    }

    @Test func scanSkipsSymbolicLinkCycles() throws {
        try withDirectory { directory in
            let source = try write("a.srt", in: directory)
            try FileManager.default.createSymbolicLink(
                at: directory.appendingPathComponent("loop"), withDestinationURL: directory
            )
            try FileManager.default.createSymbolicLink(
                at: directory.appendingPathComponent("alias.srt"), withDestinationURL: source
            )
            let scanned = SubtitleBatch.scan([directory])
            #expect(scanned.files == [source])
            #expect(scanned.issues.isEmpty)
        }
    }

    @Test func mixedValidAndInvalidImportsReportEveryFailure() throws {
        try withDirectory { directory in
            let valid = try write("valid.srt", in: directory)
            let invalid = try write("invalid.srt", in: directory, text: "1\nbad timing\ntext")
            let missing = directory.appendingPathComponent("missing.srt")
            let result = SubtitleBatch.importFiles([directory, missing])
            #expect(result.files.map(\.url) == [valid])
            #expect(Set(result.issues.map(\.url)) == Set([invalid, missing]))
            #expect(result.issues.allSatisfy { !$0.message.isEmpty })
        }
    }

    @Test func emptyFoldersAndUnsupportedFilesAreExplicitErrors() throws {
        try withDirectory { directory in
            let empty = SubtitleBatch.importFiles([directory])
            #expect(empty.files.isEmpty)
            #expect(empty.issues.count == 1)
            #expect(empty.issues[0].message.contains("没有找到"))
            let text = try write("notes.txt", in: directory)
            let unsupported = SubtitleBatch.importFiles([text])
            #expect(unsupported.files.isEmpty)
            #expect(unsupported.issues.count == 1)
        }
    }

    @Test func sameBasenamesAndExistingOutputsNeverOverwrite() throws {
        try withDirectory { directory in
            let first = try write("first/movie.srt", in: directory)
            let second = try write("second/movie.srt", in: directory)
            let output = directory.appendingPathComponent("output")
            let existing = try write("output/movie.vtt", in: directory, text: "keep existing")
            let numbered = try write("output/movie (2).vtt", in: directory, text: "keep numbered")
            let imported = SubtitleBatch.importFiles([first, second])
            let result = SubtitleBatch.exportFiles(imported.files, format: .webVTT, directory: output)
            #expect(result.issues.isEmpty)
            #expect(result.destinations.map(\.lastPathComponent) == ["movie (3).vtt", "movie (4).vtt"])
            #expect(try String(contentsOf: existing, encoding: .utf8) == "keep existing")
            #expect(try String(contentsOf: numbered, encoding: .utf8) == "keep numbered")
            for url in result.destinations {
                #expect(try Data(contentsOf: url) == imported.files[0].document.export(.webVTT))
            }
        }
    }

    @Test func everyFormatExportsOnlyChosenFilesWithExactBytes() throws {
        try withDirectory { directory in
            let first = try write("first.srt", in: directory)
            let second = try write("second.srt", in: directory)
            let files = SubtitleBatch.importFiles([first, second]).files
            for format in ExportFormat.allCases {
                let output = directory.appendingPathComponent(format.rawValue)
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
                let result = SubtitleBatch.exportFiles(Array(files.prefix(1)), format: format, directory: output)
                #expect(result.issues.isEmpty)
                #expect(result.destinations.count == 1)
                #expect(result.destinations[0].pathExtension == format.fileExtension)
                #expect(try Data(contentsOf: result.destinations[0]) == files[0].document.export(format))
                #expect(try FileManager.default.contentsOfDirectory(atPath: output.path).count == 1)
            }
            #expect(try Data(contentsOf: first) == Data(subtitle.utf8))
            #expect(try Data(contentsOf: second) == Data(subtitle.utf8))
        }
    }

    @Test func exportingIntoSourceFolderProtectsAllSources() throws {
        try withDirectory { directory in
            let first = try write("movie.srt", in: directory)
            let second = try write("movie-windows.srt", in: directory)
            let result = SubtitleBatch.exportFiles(
                SubtitleBatch.importFiles([first, second]).files, format: .windowsSRT, directory: directory
            )
            #expect(result.issues.isEmpty)
            #expect(result.destinations.count == 2)
            #expect(!result.destinations.contains(first))
            #expect(!result.destinations.contains(second))
            #expect(result.destinations.contains(directory.appendingPathComponent("movie-windows (2).srt")))
            #expect(try Data(contentsOf: first) == Data(subtitle.utf8))
            #expect(try Data(contentsOf: second) == Data(subtitle.utf8))
        }
    }

    @Test func invalidOutputDirectoryReportsEachFileWithoutSuccess() throws {
        try withDirectory { directory in
            let first = try write("first.srt", in: directory)
            let second = try write("second.srt", in: directory)
            let result = SubtitleBatch.exportFiles(
                SubtitleBatch.importFiles([first, second]).files,
                format: .plainText, directory: directory.appendingPathComponent("missing")
            )
            #expect(result.destinations.isEmpty)
            #expect(result.issues.count == 2)
            #expect(result.issues.allSatisfy { !$0.message.isEmpty })
        }
    }

    @Test func repeatedExportsCreateNewNamesAndEmptySelectionWritesNothing() throws {
        try withDirectory { directory in
            let source = try write("movie.srt", in: directory)
            let imported = SubtitleBatch.importFiles([source]).files
            let first = SubtitleBatch.exportFiles(imported, format: .markdown, directory: directory)
            let second = SubtitleBatch.exportFiles(imported, format: .markdown, directory: directory)
            #expect(first.destinations.map(\.lastPathComponent) == ["movie.md"])
            #expect(second.destinations.map(\.lastPathComponent) == ["movie (2).md"])
            let empty = SubtitleBatch.exportFiles([], format: .markdown, directory: directory)
            #expect(empty.destinations.isEmpty)
            #expect(empty.issues.isEmpty)
        }
    }
}
