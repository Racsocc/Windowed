# Windowed 变更记录

本文件用于记录项目的重要功能、修复、架构调整与协作约定。

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
