import Foundation

public struct SubtitleCue: Equatable, Sendable {
    public let number: Int
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let lines: [String]

    public var text: String { lines.joined(separator: "\n") }
}

public struct SubtitleDocument: Equatable, Sendable {
    public let cues: [SubtitleCue]

    public static func parse(data: Data) throws -> SubtitleDocument {
        try parse(text: decode(data))
    }

    public static func parse(text: String) throws -> SubtitleDocument {
        var source = text
        if source.hasPrefix("\u{FEFF}") { source.removeFirst() }
        guard !source.contains("\0") else {
            throw SubtitleError.invalidContent("文件包含 NUL 字符，无法作为字幕读取。")
        }
        source = source.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = source.components(separatedBy: "\n")
        var position = 0
        var cues: [SubtitleCue] = []

        while position < lines.count {
            if lines[position].trimmingCharacters(in: .whitespaces).isEmpty {
                position += 1
                continue
            }
            let lineNumber = position + 1
            let index = lines[position].trimmingCharacters(in: .whitespaces)
            guard isDigits(index), let number = Int(index), number > 0 else {
                throw SubtitleError.invalidLine(lineNumber, "应为正整数字幕序号。")
            }
            position += 1
            guard position < lines.count else {
                throw SubtitleError.invalidLine(lineNumber + 1, "缺少时间码。")
            }
            let timingLine = position + 1
            let parts = lines[position].components(separatedBy: "-->")
            guard parts.count == 2 else {
                throw SubtitleError.invalidLine(timingLine, "时间码应为 00:00:01,000 --> 00:00:02,000。")
            }
            let start = try parseTimestamp(parts[0].trimmingCharacters(in: .whitespaces), line: timingLine)
            let end = try parseTimestamp(parts[1].trimmingCharacters(in: .whitespaces), line: timingLine)
            guard end > start else {
                throw SubtitleError.invalidLine(timingLine, "结束时间必须晚于开始时间。")
            }
            position += 1
            var body: [String] = []
            while position < lines.count,
                  !lines[position].trimmingCharacters(in: .whitespaces).isEmpty {
                body.append(lines[position])
                position += 1
            }
            guard !body.isEmpty else {
                throw SubtitleError.invalidLine(position + 1, "字幕正文不能为空。")
            }
            cues.append(SubtitleCue(number: number, startMilliseconds: start,
                                    endMilliseconds: end, lines: body))
        }
        guard !cues.isEmpty else {
            throw SubtitleError.invalidContent("文件为空或没有有效的 SRT 字幕。")
        }
        return SubtitleDocument(cues: cues)
    }

    public func export(_ format: ExportFormat) -> Data {
        switch format {
        case .webVTT:
            let blocks = cues.map { cue in
                "\(cue.number)\n\(Self.timestamp(cue.startMilliseconds, separator: ".")) --> \(Self.timestamp(cue.endMilliseconds, separator: "."))\n"
                + cue.lines.map(Self.escapeVTT).joined(separator: "\n")
            }
            return Data(("WEBVTT\n\n" + blocks.joined(separator: "\n\n") + "\n").utf8)
        case .windowsSRT:
            let blocks = cues.map { cue in
                "\(cue.number)\r\n\(Self.timestamp(cue.startMilliseconds)) --> \(Self.timestamp(cue.endMilliseconds))\r\n"
                + cue.lines.joined(separator: "\r\n")
            }
            return Data([0xEF, 0xBB, 0xBF])
                + Data((blocks.joined(separator: "\r\n\r\n") + "\r\n").utf8)
        case .plainText:
            return Data((cues.map(\.text).joined(separator: "\n\n") + "\n").utf8)
        case .markdown:
            let blocks = cues.map { cue in
                cue.lines.map(Self.escapeMarkdown).joined(separator: "  \n")
            }
            return Data((blocks.joined(separator: "\n\n") + "\n").utf8)
        }
    }

    public static func timestamp(_ milliseconds: Int, separator: String = ",") -> String {
        let hours = milliseconds / 3_600_000
        let minutes = milliseconds / 60_000 % 60
        let seconds = milliseconds / 1_000 % 60
        let remainder = milliseconds % 1_000
        return String(format: "%02lld:%02lld:%02lld%@%03lld",
                      Int64(hours), Int64(minutes), Int64(seconds), separator, Int64(remainder))
    }

    private static func parseTimestamp(_ value: String, line: Int) throws -> Int {
        let fields = value.components(separatedBy: ":")
        guard fields.count == 3 else { throw invalidTimestamp(line) }
        let seconds = fields[2].components(separatedBy: ",")
        guard fields[0].count >= 2, fields[1].count == 2, seconds.count == 2,
              seconds[0].count == 2, seconds[1].count == 3,
              fields.allSatisfy({ !$0.isEmpty }),
              isDigits(fields[0]), isDigits(fields[1]),
              isDigits(seconds[0]), isDigits(seconds[1]),
              let hours = Int(fields[0]), let minutes = Int(fields[1]),
              let wholeSeconds = Int(seconds[0]), let millis = Int(seconds[1]),
              minutes < 60, wholeSeconds < 60 else { throw invalidTimestamp(line) }
        let (hourMillis, multiplyOverflow) = hours.multipliedReportingOverflow(by: 3_600_000)
        let (total, additionOverflow) = hourMillis.addingReportingOverflow(
            minutes * 60_000 + wholeSeconds * 1_000 + millis
        )
        guard !multiplyOverflow, !additionOverflow else { throw invalidTimestamp(line) }
        return total
    }

    private static func invalidTimestamp(_ line: Int) -> SubtitleError {
        .invalidLine(line, "无效时间码。请使用 HH:MM:SS,mmm；分、秒必须为 00–59，毫秒为三位数字。")
    }

    private static func isDigits(_ text: String) -> Bool {
        !text.isEmpty && text.utf8.allSatisfy { (48...57).contains($0) }
    }

    private static func decode(_ data: Data) throws -> String {
        let bytes = Array(data)
        if bytes.starts(with: [0xFF, 0xFE, 0x00, 0x00]) || bytes.starts(with: [0x00, 0x00, 0xFE, 0xFF]) {
            throw SubtitleError.invalidContent("暂不支持 UTF-32 编码，请先将文件另存为 UTF-8。")
        }
        if bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF]) {
            let littleEndian = bytes[0] == 0xFF
            guard (bytes.count - 2).isMultiple(of: 2) else { throw SubtitleError.invalidEncoding }
            var units: [UInt16] = []
            for offset in stride(from: 2, to: bytes.count, by: 2) {
                let first = UInt16(bytes[offset])
                let second = UInt16(bytes[offset + 1])
                units.append(littleEndian ? first | (second << 8) : (first << 8) | second)
            }
            var offset = 0
            while offset < units.count {
                let unit = units[offset]
                if (0xD800...0xDBFF).contains(unit) {
                    guard offset + 1 < units.count,
                          (0xDC00...0xDFFF).contains(units[offset + 1]) else {
                        throw SubtitleError.invalidEncoding
                    }
                    offset += 2
                } else {
                    guard !(0xDC00...0xDFFF).contains(unit) else { throw SubtitleError.invalidEncoding }
                    offset += 1
                }
            }
            return String(decoding: units, as: UTF16.self)
        }
        let payload = bytes.starts(with: [0xEF, 0xBB, 0xBF]) ? Data(bytes.dropFirst(3)) : data
        guard let text = String(data: payload, encoding: .utf8) else {
            throw SubtitleError.invalidEncoding
        }
        return text
    }

    private static func escapeVTT(_ line: String) -> String {
        line.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeMarkdown(_ line: String) -> String {
        let punctuation = Set("\\`*_{}[]<>#+-.!|~".map { $0 })
        var body = line
        var indentation = ""
        // Prevent indentation from turning literal subtitle lines into Markdown code blocks.
        while body.hasPrefix(" ") || body.hasPrefix("\t") {
            indentation += body.removeFirst() == "\t" ? "&#9;" : "&#32;"
        }
        return indentation + body.map { character in
            if character == "&" { return "&amp;" }
            return punctuation.contains(character) ? "\\" + String(character) : String(character)
        }.joined()
    }
}

public enum SubtitleError: LocalizedError, Equatable {
    case invalidEncoding
    case invalidContent(String)
    case invalidLine(Int, String)

    public var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            "无法解码字幕。支持 UTF-8（有无 BOM）及带 BOM 的 UTF-16；请将其他编码另存为 UTF-8，不会自动替换乱码。"
        case .invalidContent(let message):
            message
        case .invalidLine(let line, let message):
            "第 \(line) 行：\(message)"
        }
    }
}
