public enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case webVTT
    case windowsSRT
    case plainText
    case markdown

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .webVTT: "WebVTT"
        case .windowsSRT: "Windows SRT"
        case .plainText: "纯文本 TXT"
        case .markdown: "纯文本 Markdown"
        }
    }

    public var fileExtension: String {
        switch self {
        case .webVTT: "vtt"
        case .windowsSRT: "srt"
        case .plainText: "txt"
        case .markdown: "md"
        }
    }

    public var detail: String {
        switch self {
        case .webVTT: "保留时间码与分段 · UTF-8 · LF"
        case .windowsSRT: "保留时间码与分段 · UTF-8 BOM · CRLF"
        case .plainText: "去掉序号与时间码 · 保留正文分段"
        case .markdown: "去掉序号与时间码 · 正文按字面转义"
        }
    }
}
