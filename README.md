# 字幕转换工具

原生 macOS SwiftUI 离线批量应用，导入 SRT 文件或文件夹并导出 WebVTT、Windows 兼容 SRT、无时间码 TXT 或 Markdown。无需第三方依赖，不联网、不上传字幕，不提供字幕编辑、识别或翻译。

界面采用适配系统浅色、深色外观的纯色背景和卡片、单一系统强调色、细分隔线及克制的圆角，不使用渐变、模糊或玻璃材质。窗口保留系统原生红绿灯，不自行绘制或改写系统按钮。界面为文件工作台，不再显示字幕正文预览。添加操作放在独立操作行；列表标题使用“全选”复选框和直接可见的“清空”按钮，无折叠菜单。默认窗口为 1100 × 820，最低内容尺寸为 940 × 740，保证关键操作与导出卡片可见。

macOS 应用图标为纯蓝色圆角方形，叠放浅蓝与白色文档，白色文档带三行蓝色字幕横线，右下角橙色徽标为白色循环转换箭头。无渐变和阴影；1024 PNG 画布四周透明留白。构建时生成完整 `AppIcon.iconset`（16–1024，包含 @1x/@2x）及嵌入应用包的 `AppIcon.icns`。原始 1024 PNG 预览为 `dist/AppIcon-1024.png`，发布压缩包同时包含图标源文件、所有尺寸的 PNG 图标集和 `.icns` 应用。

## 运行

要求 macOS 13 或更高版本。已构建的本机应用位于 `dist/SubtitleConverter.app`，双击打开，或在项目目录运行：

```sh
open dist/SubtitleConverter.app
```

此应用使用本机临时签名，未经过 Apple 公证，适用于本机使用；不是可分发的 Developer ID 安装包。生成的二进制与构建机器架构一致。

## 使用

1. 在上方操作行添加字幕（文件选择器支持多选，`⌘O`），或添加文件夹（`⇧⌘O`）。也可一次拖入多个文件和文件夹。
2. 文件夹递归查找全部 `.srt`（不区分大小写），跳过隐藏项目、软件包内部和符号链接，避免循环或越出所选目录。不支持 VTT 等其他输入格式。
3. 成功导入的文件默认勾选；可逐项取消、全选或取消全选。同一路径只保留一行，再次导入会更新成功解析的内容并重新选中。不同目录的同名文件保留为独立项目，列表显示来源目录和字幕条数。
4. 选择一种导出格式，点击“导出 N 个文件”并选择输出目录（`⇧⌘E`）。所有选中文件分别导出到该目录；子文件夹结构不复制。

导出不覆盖任何已有文件。输出名保留原文件名，Windows SRT 添加 `-windows`；遇到已有输出或同名输入自动使用 `文件名 (2).vtt`、`文件名 (3).vtt` 等。即使另一进程在检查后创建同名文件，排他写入也会报错而不覆盖。可以导出到源文件夹，源文件始终受保护。

无效文件不会加入列表；其他有效文件仍会导入并默认选中。可滚动、可复制的处理报告显示所有失败项目的路径、原因及时间码行号。导出显示成功和失败数量；个别失败不会阻止其他文件导出。清空列表仅移除应用中的项目，不删除磁盘文件。导入时保存已解析的快照；源文件后来修改时，请重新导入或清空后导入。

| 格式 | 编码与换行 | 内容 |
| --- | --- | --- |
| WebVTT `.vtt` | UTF-8，无 BOM，LF | `WEBVTT` 头、毫秒点分隔时间码、原序号与多行正文 |
| Windows SRT `.srt` | UTF-8 BOM，CRLF | 原序号、逗号分隔时间码、原字幕分段 |
| TXT `.txt` | UTF-8，无 BOM，LF | 去掉序号与时间码，段间空行，保留段内换行 |
| Markdown `.md` | UTF-8，无 BOM，LF | 仅正文，段间空行，段内硬换行，转义 Markdown 语法 |

字幕正文按**字面文本**处理：不解析或移除 SRT 内的 HTML 样式标签。WebVTT 转义 `&`、`<`、`>` 以保持字面正文且避免 `-->` 破坏语法；Markdown 转义标点及实体，避免正文意外变成标题、列表或 HTML。

### 输入约定

- 支持 UTF-8（有无 BOM），以及带 BOM 的 UTF-16 LE/BE，支持中文、emoji 和 Unicode。
- 支持 LF、CRLF、CR 换行，字幕段内可有多行正文，空白行分隔字幕段。
- 每段必须有正整数序号、`HH:MM:SS,mmm --> HH:MM:SS,mmm` 时间码和非空正文；时可多于两位，分、秒必须在 00–59，结束时间必须晚于开始时间。
- 保留输入序号和字幕顺序，不重新排序；允许不连续序号或重叠字幕。
- 不猜测 GBK、ANSI 等旧编码，不替换无效 Unicode、不跳过无效时间码、不接受 VTT 作为输入。请将旧编码文件先另存为 UTF-8。
- 扩展时间码参数（如 SRT 位置坐标）不支持，按无效时间码报告。

## 构建与测试

安装 Xcode Command Line Tools（`xcode-select --install`）或完整 Xcode。要求 Swift 6.0 或更高版本及 macOS SDK。无需创建 Xcode 工程，Swift Package 可直接构建；也可用 Xcode 打开 `Package.swift`。应用最低部署版本仍为 macOS 13；构建脚本在签名前将二进制的 SDK 版本标记设为当前 macOS SDK，以启用对应的系统窗口外观。当前工具链的 Swift Testing 运行器要求 macOS 14 或更高版本。

```sh
bash scripts/test.sh
bash scripts/build-app.sh
open dist/SubtitleConverter.app
```

可使用原生 `NSHostingView` 渲染器生成浅色或深色界面预览 PNG（默认尺寸 1100 × 820、2× 分辨率）：

```sh
dist/SubtitleConverter.app/Contents/MacOS/SubtitleConverter \
  --render-preview dist/SubtitleConverter-v1.2-light.png Examples/sample.srt
dist/SubtitleConverter.app/Contents/MacOS/SubtitleConverter \
  --render-preview dist/SubtitleConverter-v1.2-dark.png Examples/sample.srt --dark
```

两张随应用包一起提供的预览图分别为 `dist/SubtitleConverter-v1.2-light.png` 和 `dist/SubtitleConverter-v1.2-dark.png`。

转换和批量逻辑在 `Sources/SubtitleCore`，界面在 `Sources/SubtitleConverter`，针对性测试使用 Swift Testing，位于 `Tests/SubtitleCoreTests`，无需 XCTest。测试脚本在本机 Command Line Tools 漏掉宏插件自动发现时显式加载已有插件；不安装外部依赖。测试覆盖递归扫描、去重、混合无效输入、四种格式、部分选择导出、重名编号、源文件保护及写入失败。`Examples/sample.srt` 可用于手动检查中文、多行字幕及四种导出结果。
