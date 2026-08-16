# Windowed 变更记录

本文件用于记录项目的重要功能、修复、架构调整与协作约定。

## 1.1.0

- 发布时间：2026-08-17
- 发布摘要：引入单 App 多窗口能力，修复网页文件上传，并优化启动恢复与窗口交互体验
- 主要变更：
  - 新增：支持单 App 多窗口，`⌘N` 可新建空白窗口
  - 新增：启动时恢复上次最后使用的单个页面
  - 修复：网页上传文件、图片、多文件选择时无法弹出访达的问题
  - 优化：History 预设在单窗口/多窗口场景下的打开逻辑，并新增明确的“新开”按钮
  - 优化：空白窗口与新开窗口的默认尺寸更符合屏幕比例
  - 优化：Dock 图标固定为默认 `Windowed` 图标，预设图标仅用于列表识别
  - 优化：Auto-start / Stop command 输入框改为更稳定的原生 AppKit 命令输入控件
- 构建产物：
  - `Windowed-1.1.0.dmg`

## 记录格式

建议每次变更使用以下结构：

### YYYY-MM-DD

- 类型：`feat` / `fix` / `docs` / `refactor` / `chore`
- 摘要：一句话说明这次改动解决了什么问题
- 涉及文件：列出主要文件
- 验证情况：说明已完成的构建、手测或回归
- 后续事项：可留空，仅在确有后续时填写

## 2026-08-16

- 类型：`docs`
- 摘要：新增多窗口与网页文件上传修复设计文档，并建立项目级变更记录文件
- 涉及文件：
  - `docs/superpowers/specs/2026-08-16-windowed-multiwindow-upload-design.md`
  - `docs/CHANGELOG.md`
- 验证情况：文档已创建，待用户审阅后进入实现阶段
- 后续事项：实现多窗口与网页文件上传修复

## 2026-08-17

- 类型：`feat`
- 摘要：实现单 App 多窗口，并修复网页文件上传无法弹出访达的问题
- 涉及文件：
  - `Sources/WebShell/App.swift`
  - `Sources/WebShell/ContentView.swift`
  - `Sources/WebShell/URLInputSheet.swift`
  - `Sources/WebShell/WebView.swift`
  - `Sources/WebShell/WindowConfig.swift`
  - `README_CN.md`
  - `README.md`
- 验证情况：已通过 `swift build --disable-sandbox` 编译
- 后续事项：继续手动验证 OpenClaw 等本地服务的多窗口和上传行为

- 类型：`docs`
- 摘要：明确 Dock 图标固定为 Windowed 默认图标，不再跟随窗口或预设变化
- 涉及文件：
  - `Sources/WebShell/URLInputSheet.swift`
  - `README_CN.md`
  - `README.md`
  - `docs/superpowers/specs/2026-08-16-windowed-multiwindow-upload-design.md`
- 验证情况：待重新构建测试包验证
- 后续事项：确认预设图标仅作为历史列表视觉标识

- 类型：`feat`
- 摘要：启动时恢复上次最后使用的单个页面，并让空白配置窗口按屏幕比例自适应尺寸
- 涉及文件：
  - `Sources/WebShell/App.swift`
  - `Sources/WebShell/ContentView.swift`
  - `Sources/WebShell/WindowConfig.swift`
  - `README_CN.md`
  - `README.md`
  - `docs/superpowers/specs/2026-08-16-windowed-multiwindow-upload-design.md`
- 验证情况：已通过 `swift build --disable-sandbox` 编译
- 后续事项：手动验证启动恢复页面与空白窗口尺寸在不同屏幕下的体验
