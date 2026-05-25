# feishucaozuo

基于 `lark-cli` 编排的飞书工作流集合。把 IM、日历、文档、多维表格、妙记等单点能力组合成可复用的业务流程。

## 这是什么

不是一个新的 SDK，也不重复封装飞书 OpenAPI。它是**工作流层**：

- 上游依赖 `lark-cli` 提供的原子命令（im / calendar / docs / base / minutes / vc …）
- 在它之上写**面向场景**的脚本：日报汇总、会议纪要分发、待办同步、跨系统通知等
- 每个 workflow 一份独立脚本 + 一份说明文档，便于按需挑用

## 目录结构

```
.
├── workflows/    # 业务工作流脚本（一个场景一个目录）
├── scripts/      # 通用工具脚本、可复用片段
├── examples/     # 最小可运行示例
├── docs/         # 设计笔记、API 调研、踩坑记录
└── CLAUDE.md     # 给 Claude Code 的项目指令
```

## 前置条件

- 已安装并登录 `lark-cli`（首次使用见 `lark-shared` skill）
- macOS / Linux，zsh 或 bash
- Node.js ≥ 18（lark-cli 依赖）

## 快速开始

```bash
# 1. 确认 lark-cli 已登录
lark-cli auth whoami

# 2. 运行示例
./examples/hello-im.sh
```

## 开发约定

参见 `CLAUDE.md`。核心几条：

- 工作流脚本优先复用 `lark-*` skill，不直接打 OpenAPI
- 涉及发消息、改文档、建日程等**写操作**前，先在脚本里打印将要执行的动作，必要时 dry-run
- 敏感信息（token、chat_id、open_id）走环境变量或本地 `.env`，**不入库**
