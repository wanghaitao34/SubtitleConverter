import Foundation
import Testing
@testable import SubtitleCore

struct SubtitleDocumentTests {
    private let sample = """
    1
    00:00:01,005 --> 00:00:03,120
    你好，世界！🌏
    Hello & <world> -->

    7
    01:02:03,004 --> 01:02:05,999
    # 第二段
    """

    @Test func unicodeMultilineAndNonsequentialNumbers() throws {
        let document = try SubtitleDocument.parse(data: Data(sample.utf8))
        #expect(document.cues.count == 2)
        #expect(document.cues[0].number == 1)
        #expect(document.cues[0].startMilliseconds == 1_005)
        #expect(document.cues[0].endMilliseconds == 3_120)
        #expect(document.cues[0].text == "你好，世界！🌏\nHello & <world> -->")
        #expect(document.cues[1].number == 7)
        #expect(document.cues[1].startMilliseconds == 3_723_004)
    }

    @Test func utf8BOMAndAllLineEndings() throws {
        let expected = try SubtitleDocument.parse(text: sample)
        for newline in ["\n", "\r\n", "\r"] {
            let source = "\u{FEFF}\n\n" + sample.replacingOccurrences(of: "\n", with: newline) + newline + newline
            #expect(try SubtitleDocument.parse(data: Data(source.utf8)) == expected)
        }
    }

    @Test func utf16BOMInBothByteOrders() throws {
        let expected = try SubtitleDocument.parse(text: sample)
        for littleEndian in [true, false] {
            var bytes: [UInt8] = littleEndian ? [0xFF, 0xFE] : [0xFE, 0xFF]
            for unit in sample.utf16 {
                let low = UInt8(unit & 0xFF)
                let high = UInt8(unit >> 8)
                bytes += littleEndian ? [low, high] : [high, low]
            }
            #expect(try SubtitleDocument.parse(data: Data(bytes)) == expected)
        }
    }

    @Test func invalidUnicodeNeverReplaced() {
        for bytes: [UInt8] in [
            [0xFF], [0xC3, 0x28], [0xEF, 0xBB, 0xBF, 0xFF],
            [0xFF, 0xFE, 0x00], [0xFF, 0xFE, 0x00, 0xD8],
            [0xFF, 0xFE, 0x00, 0xDC], [0xFE, 0xFF, 0xD8, 0x00, 0x00, 0x61],
            [0xFF, 0xFE, 0x00, 0x00], [0x00, 0x00, 0xFE, 0xFF]
        ] {
            #expect(throws: SubtitleError.self) { try SubtitleDocument.parse(data: Data(bytes)) }
        }
    }

    @Test func emptyAndNULInputRejected() {
        for source in ["", "\u{FEFF}", " \r\n\t\n", sample + "\0"] {
            #expect(throws: SubtitleError.self) { try SubtitleDocument.parse(text: source) }
        }
    }

    @Test func malformedBlocksRejected() {
        for source in [
            "hello",
            "0\n00:00:01,000 --> 00:00:02,000\ntext",
            "-1\n00:00:01,000 --> 00:00:02,000\ntext",
            "一\n00:00:01,000 --> 00:00:02,000\ntext",
            "1",
            "1\nnot a timestamp\ntext",
            "1\n00:00:01,000 --> 00:00:02,000",
            "1\n00:00:01,000 --> 00:00:02,000\n \n",
            sample + "\n\n2\n00:99:00,000 --> 01:00:00,000\nbad"
        ] {
            #expect(throws: SubtitleError.self) { try SubtitleDocument.parse(text: source) }
        }
    }

    @Test func timestampValidationAndOverflow() {
        for timestamp in [
            "00:60:00,000", "00:00:60,000", "00:00:01,00", "00:00:01,0000",
            "00:00:01.000", "0:00:01,000", "00:0:01,000", "00:00:1,000",
            "-1:00:00,000", "00:00:01,00x", "００:00:01,000",
            "99999999999999999999999:00:00,000", "2562047788016:00:00,000",
            "00:00:01,000 X1:0 X2:10", "00:00:01,000 --> 00:00:02,000"
        ] {
            let source = "1\n\(timestamp) --> 99:00:00,000\ntext"
            #expect(throws: SubtitleError.self) { try SubtitleDocument.parse(text: source) }
        }
    }

    @Test func endMustBeLaterThanStart() {
        for end in ["00:00:01,005", "00:00:00,999"] {
            #expect(throws: SubtitleError.self) { try SubtitleDocument.parse(text: "1\n00:00:01,005 --> \(end)\ntext") }
        }
    }

    @Test func errorsHaveSourceLineNumbers() {
        do {
            _ = try SubtitleDocument.parse(text: "\n\n1\n00:60:00,000 --> 01:00:00,000\ntext")
            Issue.record("Expected source line error")
        } catch {
            guard case SubtitleError.invalidLine(let line, _) = error else {
                Issue.record("Expected source line error, got \(error)")
                return
            }
            #expect(line == 4)
            #expect(error.localizedDescription.contains("第 4 行"))
        }
    }

    @Test func longHoursAndMillisecondBoundaries() throws {
        let document = try SubtitleDocument.parse(text: """
        1
        99:59:59,999 --> 100:00:00,001
        text
        """)
        #expect(document.cues[0].endMilliseconds - document.cues[0].startMilliseconds == 2)
        #expect(SubtitleDocument.timestamp(document.cues[0].startMilliseconds) == "99:59:59,999")
        #expect(SubtitleDocument.timestamp(document.cues[0].endMilliseconds, separator: ".") == "100:00:00.001")
    }

    @Test func exactCompliantWebVTT() throws {
        let output = try SubtitleDocument.parse(text: sample).export(.webVTT)
        #expect(String(decoding: output, as: UTF8.self) == """
        WEBVTT

        1
        00:00:01.005 --> 00:00:03.120
        你好，世界！🌏
        Hello &amp; &lt;world&gt; --&gt;

        7
        01:02:03.004 --> 01:02:05.999
        # 第二段

        """)
        #expect(!output.starts(with: [0xEF, 0xBB, 0xBF]))
        #expect(!output.contains(0x0D))
    }

    @Test func windowsSRTBOMCRLFAndLosslessRoundTrip() throws {
        let document = try SubtitleDocument.parse(text: sample)
        let output = document.export(.windowsSRT)
        #expect(Array(output.prefix(3)) == [0xEF, 0xBB, 0xBF])
        #expect(String(decoding: output, as: UTF8.self).filter { $0 == "\u{FEFF}" }.count == 1)
        #expect(String(decoding: output.dropFirst(3), as: UTF8.self)
                == sample.replacingOccurrences(of: "\n", with: "\r\n") + "\r\n")
        let bytes = Array(output)
        for offset in bytes.indices where bytes[offset] == 0x0A {
            #expect(offset > 0)
            #expect(bytes[offset - 1] == 0x0D)
        }
        for offset in bytes.indices where bytes[offset] == 0x0D {
            #expect(offset + 1 < bytes.count)
            #expect(bytes[offset + 1] == 0x0A)
        }
        #expect(try SubtitleDocument.parse(data: output) == document)
    }

    @Test func plainTextHasOnlyOrderedBodies() throws {
        let output = try SubtitleDocument.parse(text: sample).export(.plainText)
        #expect(String(decoding: output, as: UTF8.self)
                == "你好，世界！🌏\nHello & <world> -->\n\n# 第二段\n")
        #expect(!output.starts(with: [0xEF, 0xBB, 0xBF]))
    }

    @Test func markdownEscapesSyntaxAndPreservesLineBreaks() throws {
        let document = try SubtitleDocument.parse(text: """
        1
        00:00:00,000 --> 00:00:01,000
        # 标题 *不是粗体*
        [链接](地址) <b> &amp; &#9;

        2
        00:00:01,000 --> 00:00:02,000
            缩进
        \t制表
        """)
        #expect(String(decoding: document.export(.markdown), as: UTF8.self)
                == "\\# 标题 \\*不是粗体\\*  \n\\[链接\\](地址) \\<b\\> &amp;amp; &amp;\\#9;\n\n&#32;&#32;&#32;&#32;缩进  \n&#9;制表\n")
    }

    @Test func textWhitespaceIsNotTrimmed() throws {
        let document = try SubtitleDocument.parse(text: " 1 \n 00:00:00,000 --> 00:00:00,001 \n  正文  \n")
        #expect(document.cues[0].text == "  正文  ")
        #expect(String(decoding: document.export(.plainText), as: UTF8.self) == "  正文  \n")
    }

    @Test func overlappingCuesKeepInputOrder() throws {
        let document = try SubtitleDocument.parse(text: """
        4
        00:00:02,000 --> 00:00:04,000
        先出现

        4
        00:00:01,000 --> 00:00:03,000
        后出现
        """)
        #expect(document.cues.map(\.number) == [4, 4])
        #expect(String(decoding: document.export(.plainText), as: UTF8.self) == "先出现\n\n后出现\n")
    }

    @Test func everyFormatHasMatchingExtension() {
        #expect(ExportFormat.allCases.map(\.fileExtension) == ["vtt", "srt", "txt", "md"])
        #expect(ExportFormat.allCases.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty })
    }

    @Test func allFormatsWriteReadableFilesWithoutChangingSource() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubtitleConverterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer {
            do { try FileManager.default.removeItem(at: directory) }
            catch { Issue.record("Cannot clean test directory: \(error)") }
        }
        let sourceURL = directory.appendingPathComponent("source.srt")
        let sourceData = Data(sample.utf8)
        try sourceData.write(to: sourceURL)
        let document = try SubtitleDocument.parse(data: Data(contentsOf: sourceURL))
        for format in ExportFormat.allCases {
            let destination = directory.appendingPathComponent("output.\(format.fileExtension)")
            let expected = document.export(format)
            try expected.write(to: destination, options: .atomic)
            let actual = try Data(contentsOf: destination)
            #expect(actual == expected)
            #expect(String(data: actual, encoding: .utf8) != nil)
        }
        #expect(try Data(contentsOf: sourceURL) == sourceData)
    }
}
