# Prompt 工程学习指引

> 基于 Anthropic 交互式 Prompt 教程总结

## 课程概述

本教程帮助你掌握如何在 Claude 中编写最优提示词。

### 学习目标

- 掌握好提示词的基本结构
- 识别常见失败模式，学习 80/20 技巧解决它们
- 理解 Claude 的优势与劣势
- 从零开始构建强大的提示词

### 课程结构

共 9 章，每章包含课程和练习，另有高级方法附录。

---

## 目录速览

### 入门
- 第 1 章：基本提示词结构
- 第 2 章：清晰直接
- 第 3 章：分配角色

### 进阶
- 第 4 章：分离数据与指令
- 第 5 章：格式化输出 & 代表 Claude 发言
- 第 6 章：预认知（逐步思考）
- 第 7 章：使用示例

### 高级
- 第 8 章：避免幻觉
- 第 9 章：构建复杂提示词（行业用例）

---

## 核心要点总结

### 1. 基本结构
- 明确任务目标
- 提供必要上下文
- 清晰说明输出格式

### 2. 清晰直接
- 避免模糊表述
- 使用具体例子
- 明确期望结果

### 3. 角色分配
- 给 Claude 设定角色（如专家、助手）
- 说明专业背景和视角

### 4. 分离数据与指令
- 将输入数据与操作指令分开
- 使用分隔符（如 ```）标记

### 5. 格式化输出
- 指定输出格式（JSON、Markdown 等）
- 使用"代表 Claude 发言"格式

### 6. 逐步思考
- 让 Claude 先思考再回答
- 使用 "Let's think step by step"

### 7. 使用示例
- 提供输入输出示例
- few-shot 学习

### 8. 避免幻觉
- 要求引用来源
- 添加不确定性表达
- 验证事实

### 9. 复杂提示词
- 聊天机器人
- 法律服务
- 金融服务
- 编程用例

---

## 相关资源

- [Anthropic 官方教程](https://github.com/anthropics/prompt-eng-interactive-tutorial)
- [答案对照表](https://docs.google.com/spreadsheets/d/1jIxjzUWG-6xBVIa2ay6yDpLyeuOh_hR_ZB75a47KX_E/edit)
- [Google Sheets 版本](https://docs.google.com/spreadsheets/d/19jzLgRruG9kjUQNKtCg1ZjdD6l6weA6qRXG5zLIAhC8/edit)

---

*注：教程使用 Claude 3 Haiku 模型，更智能的模型有 Sonnet 和 Opus*
