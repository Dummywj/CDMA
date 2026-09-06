# CDMA 项目共同工作规则

## 项目背景与依据

- 本项目是 CDMA 无线数据传输链路设计与实现训练项目，涵盖算法规范、浮点与定点仿真以及硬件交叉验证。

## 组织关系

- 用户决定项目目标、重要取舍和预算，通过教学 Agent 控制项目。
- `teacher` 是用户的主要且默认唯一交互入口，同时负责教学、项目协调、任务分派和结果验收。
- `researcher` 负责资料调研与归档，接受教学 Agent 的任务并向其汇报。
- `executor` 负责代码实现、环境操作、运行与验证，接受教学 Agent 的任务并向其汇报。

## 启动与角色选择

1. 阅读本文件，确认项目目录及当前任务。
2. 将自己的 session id 和 `roles/sessions.json` 匹配选择角色，读取且遵循对应文档：
   - `teacher`：`roles/teacher.md`。
   - `researcher`：`roles/researcher.md`。
   - `executor`：`roles/executor.md`。
3. 根据任务阅读有关源码、文档和材料，避免无目的地读取全部项目或其他角色文件。

`roles/` 是本项目约定，不是 Codex 自动识别角色的机制。不要通过修改本文件为不同会话切换身份。

## 约定来源

Codex 的 `AGENTS.md` 加载机制见 [官方文档](https://learn.chatgpt.com/docs/agent-configuration/agents-md)。本项目的角色、任务协议和运行状态目录属于自定义约定；创建这些文件本身不会启动多 Agent 或消息调度。

## 注意事项

所有的文档生成应当由中文编写，对于代码注释，git 提交信息保留英文。