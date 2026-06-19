# SETUP.md — Vineyard Mower 项目开发者快速上手

> 新成员加入项目后，按此文档完成开发环境配置。
> 只需要安装 Claude Code + 克隆仓库，然后按以下步骤操作。

---

## 1. 前置依赖

### 1.1 系统要求

- **操作系统**: Linux (Ubuntu 22.04/24.04) 或 WSL2
- **Python**: 3.10+
- **Git**: 已安装并配置

### 1.2 安装 Claude Code

```bash
# 方式一：npm 全局安装（推荐）
npm install -g @anthropic-ai/claude-code

# 方式二：直接下载
# 参考 https://docs.anthropic.com/en/docs/claude-code/overview
```

### 1.3 安装 Python 开发工具

```bash
# Python 包（pytest 用于测试，ruff 用于 lint）
pip install --user ruff pytest pytest-cov
```

验证安装：
```bash
python3 --version          # >= 3.10
pytest --version           # 可用
ruff --version             # 可用
git --version              # 可用
```

---

## 2. 克隆项目

```bash
git clone https://github.com/kris2049/vineyard_robot.git
cd vineyard_robot
```

---

## 3. 配置 Claude Code

### 3.1 创建全局配置文件

创建 `~/.claude/settings.json`：

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "your-api-key-here",
    "ANTHROPIC_BASE_URL": "https://api.anthropic.com",
    "ANTHROPIC_MODEL": "claude-sonnet-4-6",
    "CLAUDE_CODE_EFFORT_LEVEL": "max"
  }
}
```

> ⚠️ **每个团队成员自己申请 API Key**，不要共享。
> 如果使用兼容 API（如 DeepSeek、OpenRouter 等），修改 `ANTHROPIC_BASE_URL` 和 `ANTHROPIC_MODEL` 即可。

### 3.2 验证项目配置

项目自带的配置文件 `.claude/settings.json` 已注册了 `/architect` 自定义 agent，克隆后自动生效：

```bash
# 在项目目录下启动 Claude Code 后，可以输入以下命令验证：
claude
# 然后输入: /architect
# 如果能正确进入架构师 agent 角色，说明配置正常
```

### 3.3 权限允许列表（可选）

Claude Code 首次运行时可能需要你允许一些命令（如 `git`、`pytest` 等）。
可以在项目 `.claude/settings.local.json` 中预先配置（该文件不会被 Git 追踪）：

```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(python3 *)",
      "Bash(pip install *)",
      "Bash(chmod +x *)"
    ]
  }
}
```

---

## 4. 启动项目

每次开始开发时，运行认知锚定脚本：

```bash
cd vineyard_robot
./scripts/anchor.sh
```

该脚本会显示：
- Git 状态（分支、最新提交、未提交变更）
- 当前开发计划
- 三角色工作流规则提醒
- 环境工具可用性

---

## 5. 角色分工概览

| 角色 | 如何调用 | 职责 | 可以写代码？ |
|------|----------|------|-------------|
| parent_agent | 默认会话 | 基础设施 + Gate + Git | ❌ |
| architect | `/architect` | 架构设计 + Worker 审查 | ❌ |
| Worker | 按需创建 | 实现业务代码 | ✅ |

完整协作流程见 **AGENTS.md**。

---

## 6. 常用命令

```bash
# 运行测试
python3 -m pytest tests/ -v

# Lint
ruff check src/

# 运行认知锚定
./scripts/anchor.sh
```

---

## 7. 常见问题

### Q: 没有 ROS 2 环境能开发吗？
可以。ROS 2 是部署目标环境，大部分业务逻辑（运动学、感知算法等）可以用纯 Python 开发和测试。

### Q: 使用不同的模型有影响吗？
没有。项目工作流不依赖特定模型。只要 Claude Code 能正常工作即可。

### Q: 我的 `.claude/settings.local.json` 会被提交吗？
不会。该文件已被加入 `.gitignore`，仅本地生效。

### Q: 如何更新项目规范？
联系 parent_agent（项目维护者）更新 AGENTS.md、PROJECT.md 等核心文档。Worker 和 architect 不可修改。

---

*Happy coding! 🚀*
