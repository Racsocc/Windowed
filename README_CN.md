# Windowed

一个轻量的 macOS 壳子应用，把任意网页变成原生桌面窗口。输入 URL，就能得到一个独立的 app——有自己的 Dock 图标、窗口和标题，没有浏览器的标签栏和地址栏。

最初为 [Hermes WebUI](https://github.com/nesquena/hermes-webui) 开发，但适用于任何 URL。

## 功能

- **自定义显示名称** — 显示在窗口标题栏
- **URL 历史** — 自动记住最近 5 条 URL，一键切换
- **自定义 app 图标** — 从本地选图片作为 Dock/台前调度图标
- **零依赖** — 纯 SwiftUI + WebKit，无第三方框架
- **自包含** — 单个 .app，无需安装步骤

## 使用方法

1. 启动 `Windowed.app`
2. 输入显示名称（可选）和 URL
3. 网页在原生 macOS 窗口中加载
4. 随时按 `⌘U` 或点齿轮按钮修改 URL

### 自定义图标

在设置弹窗中，点击 **Set App Icon**，选择 `.png`、`.jpg`、`.icns` 或 `.tiff` 文件。图标会跨启动持久保存。点击 **Remove Icon** 恢复默认图标。

### 分享给他人

应用未签名，接收方需要：

```bash
# 去除隔离标记 + ad-hoc 签名
xattr -cr /Applications/Windowed.app
codesign --force --deep --sign - /Applications/Windowed.app
```

或者首次打开时右键 → 打开。

## 构建

需要 macOS 14+ 和 Xcode Command Line Tools。

```bash
# 构建 release 版本
cd /path/to/Windowed
swift build -c release

# 创建 .app 包
mkdir -p Windowed.app/Contents/MacOS Windowed.app/Contents/Resources
cp .build/release/Windowed Windowed.app/Contents/MacOS/
cp Info.plist Windowed.app/Contents/

# 可选：添加自定义图标
cp Windowed.icns Windowed.app/Contents/Resources/

# 移动到 Applications
mv Windowed.app /Applications/

# 清理构建缓存
rm -rf .build
```

## 项目结构

```
Windowed/
├── Package.swift              # Swift Package Manager 配置
├── Info.plist                 # App bundle 元数据
├── Windowed.icns              # 默认 app 图标
├── README.md                  # 英文说明
├── README_CN.md               # 中文说明（本文件）
└── Sources/WebShell/          # 源代码
    ├── App.swift              # 应用入口，窗口配置
    ├── ContentView.swift      # 主视图，工具栏，URL 状态管理
    ├── WebView.swift          # WKWebView 封装（NSViewRepresentable）
    └── URLInputSheet.swift    # 设置弹窗：URL 输入、名称、图标、历史
```

## 技术栈

- **Swift 6.3** + **SwiftUI** — 应用框架
- **WKWebView**（WebKit）— 网页渲染
- **NSViewRepresentable** — 将 WKWebView 桥接到 SwiftUI
- **UserDefaults** — 持久化存储 URL、名称、图标路径、历史记录
- **NSOpenPanel** — 自定义图标的文件选择器

无第三方依赖。一个 `Package.swift`，四个源文件。

## 架构

```
┌─────────────────────────────────────────────┐
│  WindowedApp (@main)                        │
│  ├─ 从存储加载已保存的 URL/名称/图标         │
│  ├─ 首次启动时显示 URLInputSheet             │
│  └─ WindowGroup → ContentView               │
├─────────────────────────────────────────────┤
│  ContentView                                │
│  ├─ 工具栏：标题 | 设置 | 刷新               │
│  ├─ 空状态 → 设置 URL 按钮                   │
│  └─ 加载状态 → WebView                      │
├─────────────────────────────────────────────┤
│  WebView (NSViewRepresentable)              │
│  ├─ 封装 WKWebView 供 SwiftUI 使用           │
│  ├─ 处理导航、错误                           │
│  └─ 用网页标题更新窗口标题                   │
├─────────────────────────────────────────────┤
│  URLInputSheet                              │
│  ├─ 显示名称 + URL 输入                      │
│  ├─ 历史列表（最多 5 条）                    │
│  └─ 图标选择器（NSOpenPanel → bundle）       │
└─────────────────────────────────────────────┘
```

## 许可

个人使用，随便折腾。
