# feishucaozuo - 项目指令

## 项目定位

基于 `lark-cli` 编排飞书工作流。**不**重新封装飞书 OpenAPI，而是把已有 skill / CLI 命令组合成可复用的业务脚本。

## 优先级

需要操作飞书时，按下面顺序选工具：

1. **现有 lark-\* skill**（lark-im / lark-calendar / lark-doc / lark-base / lark-minutes / lark-vc / lark-sheets …）—— 默认首选
2. **lark-cli 已注册命令** —— skill 没覆盖但 CLI 已实现的，直接调
3. **lark-openapi-explorer** —— 前两者都不行时，再去查原生 OpenAPI

不要绕过 skill 直接 curl 飞书接口。

## 写工作流的约定

- 一个场景一个目录：`workflows/<场景名>/`，内含可执行脚本 + `README.md` 说明触发方式、输入输出
- 脚本顶部用中文注释写**业务目的**和**依赖的 skill/命令**
- 写操作（发消息、建日程、改文档）必须支持 `--dry-run` 或在执行前打印动作
- ID 类信息（chat_id、open_id、doc_token、app_token）不写死在脚本里，走 env 或参数

## 语言

- 业务说明、注释、文档：**中文**
- 变量名、函数名、文件名：**英文**（kebab-case 或 snake_case）
- 与 James 对话：**中文**

## 不要做

- 不自动 `git commit` / `git push`，除非 James 明确要求
- 不在仓库里塞 token、cookie、个人 open_id
- 不写"先把整个目录扫一遍"这种探索性命令到工作流脚本里，那是开发期临时操作
- 不创建过度抽象的"框架"。先把 3 个具体工作流写出来再考虑抽公共层

## 参考

- 当前可用的飞书 skill 列表见会话启动时的 skill 注入
- 复杂场景先用 `duiqi` skill 做对齐问卷，确认范围再动手
