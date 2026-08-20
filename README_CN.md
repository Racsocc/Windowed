# Windowed

一个轻量的 macOS 壳子应用，把任意网页变成原生桌面窗口。输入 URL，就能得到一个独立的 app——有自己的 Dock 图标、窗口和标题，没有浏览器的标签栏和地址栏。

最初为 [Hermes WebUI](https://github.com/nesquena/hermes-webui) 开发，但适用于任何 URL。

## 功能

- **单 App 多窗口** — 用一个 Dock 图标同时打开多个独立网页窗口，支持 `⌘N`
- **恢复上次窗口会话** — 启动时优先恢复上次关闭时的全部已配置窗口，没有记录时再进入空白配置窗口
- **自定义显示名称** — 显示在窗口标题栏
- **URL 历史** — 自动记住最近 20 条非置顶 URL，置顶常用项不限数量
- **预设自定义图标** — 从本地选 icon 作为预设列表中的视觉标识
- **本地服务自动启动** — 为本地 URL 预设 `start` 命令，打开时自动拉起服务
- **按预设可选自动停止** — 可为单个预设启用“关闭窗口时停止服务”，并单独配置 `stop` 命令
- **网页原生弹窗支持** — 支持 `alert()`、`confirm()`、`prompt()`，适配网页内删除确认、输入框等交互
- **网页文件上传支持** — 支持网页中的文件、图片、多文件选择，并弹出原生访达面板
- **外链与下载自动交给系统浏览器** — 普通链接点击、`window.open()` / `_blank` 和下载请求默认用系统浏览器处理
- **零依赖** — 纯 SwiftUI + WebKit，无第三方框架
- **自包含** — 单个 .app，无需安装步骤

## 使用方法

1. 启动 `Windowed.app`
2. 输入显示名称（可选）和 URL
3. 网页在原生 macOS 窗口中加载
4. 随时按 `⌘U` 或点齿轮按钮打开一个空白设置面板，保存后替换当前窗口内容
5. 按 `⌘N` 可新建一个空白窗口

### 多窗口

- `⌘N` 会新建一个独立窗口
- 每个窗口拥有自己的 URL、名称和服务状态
- 历史预设点击后默认在新窗口打开，不会覆盖当前窗口
- 设置面板默认始终是空白草稿，只有点击 History 的编辑按钮才会载入已有条目进入编辑态

### 启动行为

- App 启动时会优先恢复上次关闭时的全部已配置窗口
- 空白设置窗口和未保存草稿不会参与恢复
- 如果没有可恢复窗口，则打开空白配置窗口
- 空白配置窗口会按当前屏幕可视区域的约 `72%` 宽、`88%` 高自适应显示，小屏上不再固定为 800 高

### 链接与下载行为

- 在 Windowed 中点击普通超链接时，会直接交给系统默认浏览器打开
- `target="_blank"`、`window.open()` 和右键菜单里的新窗口打开请求，也会交给系统默认浏览器处理
- 下载链接和浏览器右键菜单里的下载动作会交给系统默认浏览器
- 当前壳窗口继续承载入口页本身，以及页面内部的前端路由、刷新、表单等正常运行逻辑

### 设置窗口

- 设置窗口会按屏幕可视区域自适应高度，优先控制在约 `80%` - `90%` 的范围内
- 历史记录改为独立滚动区域，条目较多时会出现滚动条，不再整体把窗口撑高

### 本地服务预设

如果你的地址是本地服务，比如 `http://127.0.0.1:18789/chat?session=main`，可以在设置面板里额外填写：

- **Start command**：例如 `~/hermes-webui/ctl.sh start`
- **Stop service when window closes**：按预设开启，默认关闭
- **Stop command**：例如 `~/hermes-webui/ctl.sh stop`

这样 Windowed 会在打开该预设时尝试启动服务；如果该窗口在下次启动时被恢复，也会继续按该条目自己的配置决定是否启动。只有你明确启用时，Windowed 才会在关闭窗口或退出 App 时执行对应的停止命令。

### 自定义图标

在设置弹窗中，点击 **Choose Icon…**，选择 `.png`、`.jpg`、`.icns` 或 `.tiff` 文件。图标会作为该预设在历史列表中的视觉标识跨启动持久保存。Dock 图标固定为 `Windowed` 默认图标，不跟随窗口或预设变化。点击 **Remove** 可移除该预设图标。

### 无法打开，因为无法验证开发者

由于应用没有经过 Apple 开发者签名和公证，可能需要：

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

# 如果遇到 sandbox 权限问题，可改用
swift build -c release --disable-sandbox

# 创建 .app 包
mkdir -p dist/Windowed.app/Contents/MacOS dist/Windowed.app/Contents/Resources
cp .build/release/Windowed dist/Windowed.app/Contents/MacOS/
cp Info.plist dist/Windowed.app/Contents/

# 可选：添加自定义图标
cp Windowed.icns dist/Windowed.app/Contents/Resources/

# 可选：ad-hoc 签名
codesign --force --deep --sign - dist/Windowed.app

# 移动到 Applications
mv dist/Windowed.app /Applications/

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
    ├── App.swift              # 应用入口，多窗口场景与菜单
    ├── ContentView.swift      # 主视图，窗口级 URL 状态与本地服务启停
    ├── ServiceStarter.swift   # 本地服务启动、健康检查、停止命令调度
    ├── WebView.swift          # WKWebView 封装，含网页弹窗与文件上传支持
    ├── WindowConfig.swift     # 窗口实例模型
    └── URLInputSheet.swift    # 设置弹窗：URL、名称、图标、历史、启停命令
```

## 技术栈

- **Swift 6.3** + **SwiftUI** — 应用框架
- **WKWebView**（WebKit）— 网页渲染
- **NSViewRepresentable** — 将 WKWebView 桥接到 SwiftUI
- **UserDefaults** — 持久化存储 URL、名称、图标路径、历史记录、启停配置
- **NSOpenPanel** — 自定义图标的文件选择器
- **Process / Timer / URLSession** — 本地服务拉起、轮询健康检查、执行停止命令

无第三方依赖。一个 `Package.swift`，五个源文件。

## 架构

```
┌─────────────────────────────────────────────┐
│  WindowedApp (@main)                        │
│  ├─ WindowGroup(for: WindowConfig)          │
│  ├─ 支持单 App 多窗口                        │
│  └─ ContentView(窗口级状态)                 │
├─────────────────────────────────────────────┤
│  ContentView                                │
│  ├─ 工具栏：标题 | 设置 | 刷新               │
│  ├─ 每个窗口独立 URL / 名称 / 服务状态       │
│  ├─ 本地预设 → ServiceStarter               │
│  └─ 加载状态 → WebView                      │
├─────────────────────────────────────────────┤
│  ServiceStarter                             │
│  ├─ 执行 start / stop 命令                  │
│  ├─ 轮询本地地址健康状态                     │
│  └─ 避免重复启动，按需停止服务               │
├─────────────────────────────────────────────┤
│  WebView (NSViewRepresentable)              │
│  ├─ 封装 WKWebView 供 SwiftUI 使用           │
│  ├─ 处理导航、外链分流、错误、JS 原生弹窗    │
│  ├─ 处理网页文件上传                         │
│  └─ 用网页标题更新窗口标题                   │
├─────────────────────────────────────────────┤
│  URLInputSheet                              │
│  ├─ 显示名称 + URL 输入                      │
│  ├─ 历史列表（20 条普通项，置顶不限，可滚动）│
│  ├─ 启动 / 停止命令配置                      │
│  └─ 图标选择器（NSOpenPanel → bundle）       │
└─────────────────────────────────────────────┘
```

## 许可

个人使用，随便折腾。
