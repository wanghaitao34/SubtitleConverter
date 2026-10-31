import SwiftUI
import SubtitleCore
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var model: ConverterModel

    var body: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)
            VStack(alignment: .leading, spacing: 24) {
                header
                importActions
                HStack(alignment: .top, spacing: 20) {
                    fileList
                        .frame(minWidth: 420)
                    exportCard.frame(width: 260)
                }
                footer
            }
            .padding(28)
        }
        .overlay {
            if model.isDropTarget {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .padding(10).allowsHitTesting(false)
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $model.isDropTarget, perform: model.acceptDrop)
        .disabled(model.isBusy)
        .sheet(isPresented: $model.showsError) {
            VStack(alignment: .leading, spacing: 16) {
                Label("处理报告", systemImage: "exclamationmark.triangle")
                    .font(.title2.bold())
                ScrollView {
                    Text(model.errorMessage).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Spacer()
                    Button("好") { model.showsError = false }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 600, height: 420)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "captions.bubble.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 6) {
                Text("让字幕，自由流转。").font(.system(size: 28, weight: .bold))
                    .fixedSize()
                Text("拖入文件或文件夹，一次完成所有字幕转换。")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize()
            }
            Spacer()
            Label("完全离线", systemImage: "lock.shield")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .modifier(SolidCard(cornerRadius: 8, bordered: true))
                .fixedSize()
        }
    }

    private var importActions: some View {
        HStack(spacing: 12) {
            Button(action: model.chooseFile) {
                Label("添加字幕", systemImage: "doc.badge.plus")
            }
            Button(action: model.chooseFolder) {
                Label("添加文件夹", systemImage: "folder.badge.plus")
            }
            Spacer()
            Text("支持多选 · 自动扫描子文件夹")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize()
        }
        .buttonStyle(.bordered)
        .tint(Color.accentColor)
        .controlSize(.large)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("字幕文件").font(.headline)
                    Text("已选 \(model.selection.count) / \(model.files.count)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("全选", isOn: Binding(
                    get: { !model.files.isEmpty && model.selection.count == model.files.count },
                    set: { selected in
                        if selected { model.selectAll() }
                        else { model.deselectAll() }
                    }
                ))
                .toggleStyle(.checkbox)
                .fixedSize()
                .disabled(model.files.isEmpty)
                Button(action: model.clear) {
                    Label("清空", systemImage: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .fixedSize()
                .help("清空列表，不删除原始文件")
                .disabled(model.files.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            Divider()
            if model.files.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text("把字幕放在这里").font(.title3.bold())
                    Text("支持多个 SRT 文件，或整个文件夹\n自动查找子文件夹中的字幕，导入后默认全选")
                        .font(.callout).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.files) { file in
                            fileRow(file)
                            Divider().padding(.leading, 58)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(SolidCard(cornerRadius: 12, bordered: true))
    }

    private func fileRow(_ file: ImportedSubtitle) -> some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { model.selection.contains(file.id) },
                set: { selected in
                    if selected { model.selection.insert(file.id) }
                    else { model.selection.remove(file.id) }
                }
            )) {
                Text("选择 \(file.url.lastPathComponent)")
            }
            .labelsHidden().toggleStyle(.checkbox)
            Image(systemName: "doc.text")
                .font(.title3).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(file.url.lastPathComponent)
                    .font(.body.weight(.medium)).lineLimit(1)
                Text(file.url.deletingLastPathComponent().path)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Text("\(file.document.cues.count) 条")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .help(file.url.path)
        .accessibilityElement(children: .contain)
    }

    private var exportCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("选择目的格式").font(.headline)
                Text("一个文件，一份输出。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                ForEach(ExportFormat.allCases) { format in
                    Button {
                        model.format = format
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(format.title).font(.callout.weight(.semibold))
                                Text("." + format.fileExtension)
                                    .font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: model.format == format ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(model.format == format ? Color.accentColor : .secondary)
                        }
                        .padding(12)
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                        .background(model.format == format ? Color.accentColor.opacity(0.08) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(model.format == format ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.08))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(format.title)
                    .accessibilityValue(model.format == format ? "已选择" : "未选择")
                }
            }
            Text(model.format.detail)
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            exportButton
            Text("选择输出目录后批量导出。\n重名自动编号，绝不覆盖原文件。")
                .font(.caption).foregroundStyle(.secondary)
            if let directory = model.outputDirectory {
                Button(action: model.revealOutput) {
                    Label(directory.lastPathComponent, systemImage: "folder")
                        .lineLimit(1)
                }
                .buttonStyle(.link)
                .help(directory.path)
            }
        }
        .padding(20)
        .modifier(SolidCard(cornerRadius: 12, bordered: true))
    }

    private var exportLabel: some View {
        Label("导出 \(model.selection.count) 个文件", systemImage: "arrow.up.doc")
            .frame(maxWidth: .infinity)
    }

    private var exportButton: some View {
        Button(action: model.exportFile) { exportLabel }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.accentColor)
            .disabled(model.selection.isEmpty)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if model.isBusy {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "checkmark.shield").foregroundStyle(Color.accentColor)
            }
            Text(model.status).font(.callout).textSelection(.enabled)
            Spacer()
        }
    }
}

private struct SolidCard: ViewModifier {
    let cornerRadius: CGFloat
    var bordered = false

    func body(content: Content) -> some View {
        content
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                if bordered {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
            }
    }
}
