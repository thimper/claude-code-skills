---
name: use-bailian
description: Switch Claude Code API to Bailian (百炼) when Anthropic API is unreachable, or restore back to Anthropic.
argument-hint: "[api-key | restore | check]"
disable-model-invocation: true
allowed-tools: Read, Edit, Bash
---

## 用途

管理 Claude Code 的 API 后端：在 Anthropic API 不可达时切换到阿里云百炼（兼容 Anthropic 协议），或恢复原始配置。

修改的文件：`~/.claude/settings.json` 的 `env` 块。**修改后需要重启 Claude Code 才能生效。**

---

## Step 1: 解析参数

读取 `$ARGUMENTS`：
- `restore` → 跳到 **Step 4**（恢复 Anthropic）
- `check` → 只执行 **Step 2**，检查连通性后停止
- 空或者一串字符串（API Key）→ 执行 **Step 2** 检查连通性，再执行 **Step 3** 切换百炼

将参数存为 `INPUT`（可能是 api-key，也可能为空）。

---

## Step 2: 检查 Anthropic API 连通性

运行以下命令（5 秒超时）：

```bash
curl -s --max-time 5 -o /dev/null -w "%{http_code}" https://api.anthropic.com/v1/models
```

- 返回 `401` 或 `200`：API **可达**（401 是未认证，但网络通了）
- 返回 `000` 或超时：API **不可达**

**如果 API 可达，且 `INPUT` 不是 api-key（即参数为空或 `check`）：**
```
✅ Anthropic API 连通正常，无需切换。
当前状态：使用 Anthropic 官方 API
如需强制切换百炼，请提供 API Key：/use-bailian <your-bailian-api-key>
```
然后停止执行。

**如果是 `check` 模式，不管结果如何，汇报后停止。**

**如果 API 不可达，或用户提供了 API Key（强制切换）：** 继续 Step 3。

---

## Step 3: 切换到百炼

### 3a: 获取 API Key

如果 `INPUT` 不为空，将其作为 `BAILIAN_KEY`。

如果 `INPUT` 为空（API 不可达，用户没提供 key），输出：
```
❌ Anthropic API 不可达。
需要您的百炼 API Key 才能切换。
请运行：/use-bailian <your-bailian-api-key>
```
然后停止。

### 3b: 读取并更新 settings.json

读取 `~/.claude/settings.json`。

在 `env` 块中添加/覆盖以下三个字段：
```json
"ANTHROPIC_AUTH_TOKEN": "<BAILIAN_KEY>",
"ANTHROPIC_BASE_URL": "https://coding.dashscope.aliyuncs.com/apps/anthropic",
"ANTHROPIC_MODEL": "qwen3.5-plus"
```

同时在 `env` 块写入一个标记，记录当前模式：
```json
"_BAILIAN_ACTIVE": "true"
```

保留文件中所有其他字段不变。用 Edit 工具精确修改。

### 3c: 输出结果

```
✅ 已切换到百炼 (Bailian) API
  端点: https://coding.dashscope.aliyuncs.com/apps/anthropic
  模型: qwen3.5-plus

⚠️  请重启 Claude Code 使配置生效。
恢复 Anthropic 官方 API：/use-bailian restore
```

---

## Step 4: 恢复 Anthropic（restore 模式）

读取 `~/.claude/settings.json`，检查 `env` 块中是否存在 `_BAILIAN_ACTIVE`。

**如果不存在：**
```
ℹ️  当前未处于百炼模式，无需恢复。
```
停止。

**如果存在，从 `env` 块删除以下字段：**
- `ANTHROPIC_AUTH_TOKEN`
- `ANTHROPIC_BASE_URL`
- `ANTHROPIC_MODEL`
- `_BAILIAN_ACTIVE`

保留其他字段不变。

输出：
```
✅ 已恢复 Anthropic 官方 API 配置
  已移除百炼相关环境变量

⚠️  请重启 Claude Code 使配置生效。
```

---

## 注意事项

- API Key 明文存储在 `~/.claude/settings.json`，该文件权限应为 600（仅用户可读）
- 百炼兼容 Anthropic 协议，Claude Code 会透明地将请求发往阿里云
- 如果 `ANTHROPIC_AUTH_TOKEN` 已在 shell 环境变量中设置，settings.json 中的值会覆盖它
