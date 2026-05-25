# workflows/

业务工作流脚本。每个场景一个子目录。

## 目录约定

```
workflows/<scenario-name>/
├── run.sh           # 入口脚本（或 run.ts / run.py）
├── README.md        # 触发方式、输入、输出、依赖
└── config.example   # 示例配置（如需要）
```

## 命名

- 用动宾或场景名：`daily-standup-digest`、`meeting-minutes-dispatch`、`base-to-im-notifier`
- 避免泛词：不要叫 `workflow1`、`test`、`tmp`

## 新增步骤

1. 用 `duiqi` skill 写一份对齐问卷，确认输入输出和触发时机
2. 在 `workflows/<name>/README.md` 里写清楚依赖哪些 skill
3. 脚本先做 dry-run 版本，确认动作正确再去掉
