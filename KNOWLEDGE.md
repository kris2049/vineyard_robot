# KNOWLEDGE.md — 项目认知与知识管理

> **版本**: 1.1.0
> **适用范围**: Vineyard Mower 项目的长期认知保持
> **目标**: 随着代码量增长，始终保持对项目的正确理解
> **核心理念**: 文档不是死的 —— 它是代码的活地图

---

## 1. 问题定义

AI 编程助手的核心瓶颈是**上下文窗口有限**。当项目从 1000 行增长到 10000 行再到 100000 行时：

| 阶段 | 代码量 | 问题 |
|------|--------|------|
| 早期 | < 5K 行 | 可以全部放入 context |
| 中期 | 5K-50K 行 | 需要选择性加载 |
| 后期 | 50K-500K 行 | 需要结构化认知系统 |
| 大规模 | > 500K 行 | 需要专门的 knowledge retrieval 系统 |

**目标**: 不论项目多大，parent_agent 和所有 Worker Agent 都能够：
- 在 < 30s 内获得当前架构的准确理解
- 知道任何符号的位置、依赖和影响范围
- 在不阅读全部代码的情况下做出正确的设计决策

---

## 2. 多层认知体系

```
Layer 5: CodeGraph 实时知识图谱 ← 精确到符号级别
Layer 4: Docs & Plans          ← 人类可读的理解
Layer 3: PROJECT.md            ← 架构蓝图
Layer 2: CLAUDE.md             ← AI 入口 Context
Layer 1: AGENTS.md             ← 工作流规则
```

### 2.1 Layer 1-2: 入口文档（始终加载）

- **AGENTS.md**: 工作流和协作规则（agent 行为）
- **CLAUDE.md**: 技术栈、关键命令、项目结构速览

这些文件保持在 **< 200 行**，始终放入 context window。

### 2.2 Layer 3: 项目蓝图（按需加载）

- **PROJECT.md**: 架构总览、安全原则、约束边界
- **COUNCIL.md**: 审查和监督体系

这些文件保持在 **< 350 行**，在需要设计决策时加载。

### 2.3 Layer 4: 详细文档（选择性加载）

- `docs/architecture/`: 各子系统架构详解
- `docs/plans/`: 实现计划和设计决策
- `docs/api/`: 接口定义和消息类型文档
- `docs/decisions/`: 设计决策记录

按需加载相关文件。

### 2.4 Layer 5: CodeGraph 知识图谱（精确查询）

**CodeGraph** 是最精确的项目认知工具。索引了 94,685 个节点和 112,404 条边。

**关键命令**:

```bash
# 快速定位
codegraph query <symbol>        # 找到任何符号
codegraph callers <symbol>      # 谁在调用
codegraph callees <symbol>      # 调用了谁
codegraph impact <symbol>       # 改动影响范围
codegraph affected <files>      # 哪些测试受影响

# 结构理解
codegraph context <task>        # 为特定任务构建 context
codegraph files                 # 浏览项目文件结构

# 状态监控
codegraph status                # 索引统计
codegraph sync                  # 同步最新变更
```

**最佳实践**:
- 每次设计决策前运行 `codegraph impact`
- 每次代码审查前运行 `codegraph affected` 确认测试覆盖
- Worker Agent 切换上下文时运行 `codegraph context` 获得子系统全貌

---

## 3. 文档活性维护策略

### 3.1 文档生成（不是手写）

```
代码 ──(自动提取)──→ 结构文档
代码 ──(CodeGraph)──→ 依赖图
代码 ──(自动生成)──→ API 文档
```

规则：**能从代码自动生成的东西，绝不手写。**

### 3.2 同步检测（Gap Detection）

```
Phase 审查时运行:
  CodeGraph 实际依赖图  vs  PROJECT.md 描述的子系统边界
  → 不一致 = 架构漂移 → 触发 Council 审查
```

### 3.3 过期标记

所有计划文档 (`docs/plans/`) 的 YAML Frontmatter 中声明：

```yaml
---
status: implemented | superseded | deprecated
superseded_by: plan-xxx.md
last_verified: 2026-06-15
---
```

---

## 4. Context 窗口管理策略

### 4.1 分层加载协议

```
Agent 启动时:
  ✅ 加载 Layer 1-2 (AGENTS.md + CLAUDE.md) — 始终

任务开始时:
  ✅ 加载 Layer 3 (PROJECT.md + COUNCIL.md)
  ✅ 运行 codegraph status 确认索引最新
  ✅ 运行 codegraph context "<task description>"  获得相关 context

任务进行中:
  ✅ codegraph query  定位符号
  ✅ codegraph impact 检查影响
  ✅ codegraph callers/callees 理解调用链

任务完成时:
  ✅ codegraph affected <changed files>  检查测试影响
  ✅ codegraph sync  更新索引
```

### 4.2 Context 预算分配

| 预算占比 | 内容 | 说明 |
|---------|------|------|
| 30% | 项目规范 (AGENTS, PROJECT, COUNCIL, CLAUDE) | 不变的基础 |
| 20% | 当前子系统文档 | 按需加载 |
| 30% | CodeGraph context 输出 | 动态生成 |
| 20% | 当前对话/代码 | 实际工作 |

---

## 5. 用 CodeGraph 实现"认知锚点"

### 5.1 概念

**认知锚点 (Cognition Anchor)** 是一组预定义的 CodeGraph 查询，在任何开发任务开始前必须运行，确保 Agent 对项目当前状态有准确认知。

### 5.2 锚点查询集

```bash
# 锚点 1: 项目全景 (Always)
codegraph status

# 锚点 2: 子系统边界 (按需)
codegraph query "src/<subsystem>/" --kind file

# 锚点 3: 接口契约 (跨子系统)
codegraph impact "src/common/types/"

# 锚点 4: 关键函数调用链 (安全审查)
codegraph callers "SafetyLimits"
codegraph callers "MotionController"

# 锚点 5: 测试覆盖率检查
codegraph affected src/<subsystem>/
```

### 5.3 自动锚点脚本

`scripts/anchor.sh`:
```bash
#!/bin/bash
# 认知锚点 — 在任何开发会话开始时运行
echo "=== CogAnchor: Project Status ==="
codegraph status --short
echo "=== CogAnchor: Interface Impact ==="
codegraph impact "src/common/types/" 2>/dev/null | head -30
echo "=== CogAnchor: Recent Changes ==="
git log --oneline -5
echo "=== Anchor Complete ==="
```

---

## 6. 项目规模升级路径

| 里程碑 | 代码量 | 新增手段 |
|--------|--------|----------|
| **当前** | < 1K 行 | CLAUDE.md + PROJECT.md + 直接阅读 |
| **Phase 1 中** | ~5K 行 | + CodeGraph context |
| **Phase 1 完** | ~15K 行 | + 自动锚点脚本 + 决策日志 |
| **Phase 2** | ~50K 行 | + RAG over docs + 自动架构同步 |
| **Phase 3+** | ~200K 行 | + 专职 Knowledge Agent + 结构化向量库 |

### 6.1 未来考虑（Phase 2+）

- **RAG 系统**: 将文档和代码嵌入向量库，支持语义搜索
- **自动同步**: CI 中运行 "架构漂移检测"，比较 CodeGraph 实际依赖图与 PROJECT.md
- **Knowledge Agent**: 一个专职 Agent 维护项目的认知一致性

---

## 7. 反模式 — 需要警惕的信号

| 信号 | 含义 | 应对 |
|------|------|------|
| "我看不到全貌" | Context 超载 | 切分任务，分而治之 |
| "文档说过但代码没有" | 文档漂移 | 触发 Council Phase 审查 |
| "这个函数还有谁在用?" | 缺少影响分析 | 运行 `codegraph callers` |
| "我不确定这个改动是否安全" | 认知缺口 | 触发 Council 审查 |
| "测试全过了但我不知道原因" | 理解不足 | 运行 `codegraph context` 重建认知 |
| "改了一个地方，另一个地方坏了" | 隐藏依赖 | 运行 `codegraph impact` 识别耦合 |

---

## 9. 推荐工具栈

基于调研，以下工具对 vineyard_robot 项目最实用：

### 9.1 当前已部署

| 工具 | 用途 | 状态 |
|------|------|------|
| **CodeGraph** | 知识图谱：查询符号、调用链、影响分析 | ✅ 已部署 |
| **Git** | 版本管理 | ✅ 已部署 |
| **CLAUDE.md** | AI 入口 context（202 行） | ✅ 已部署 |
| **PROJECT.md** | 架构蓝图（269 行） | ✅ 已部署 |
| **COUNCIL.md** | 审查监督体系 | ✅ 已部署 |
| **KNOWLEDGE.md** | 本文档 — 认知保持策略 | ✅ 已部署 |

### 9.2 推荐 Phase 1 引入

| 工具 | 用途 | 成本 | 优先级 |
|------|------|------|--------|
| **认知锚点脚本** | 每会话开始时自动运行 CodeGraph + git log | 0 | 🔴 P0 |
| **依赖图生成 (pydeps)** | Python 模块依赖可视化 | 极低 | 🟡 P1 |
| **Git hook: 索引同步** | post-commit 自动运行 `codegraph sync` | 极低 | 🟡 P1 |
| **决策日志 (ADR)** | `docs/decisions/DR-xxx.md` | 0 | 🔴 P0 |

### 9.3 推荐 Phase 2+ 引入

| 工具 | 用途 | 成本 | 优先级 |
|------|------|------|--------|
| **MCP Server** | CodeGraph 作为 MCP 服务器，Claude Code 内直接查询 | 低 | 🟡 P1 |
| **CI 架构漂移检测** | 比较 CodeGraph 实际依赖图 vs PROJECT.md | 中 | 🟢 P2 |
| **自动架构图生成** | pyreverse → Mermaid → 生成子系统关系图 | 中 | 🟢 P2 |
| **增量索引** | Git hook 触发 codegraph sync（仅更新变更文件） | 低 | 🟡 P1 |
| **RAG 检索** | 当代码量 > 50K 行时引入向量检索 | 高 | 🔵 P3 |

---

## 10. 认知锚点自动脚本

`scripts/anchor.sh` — 每个开发会话开始时自动运行：

```bash
#!/bin/bash
# Cognitive Anchor — run at start of every dev session
echo "╔══════════════════════════════════════╗"
echo "║  🧠 Cognitive Anchor — Vineyard Mower║"
echo "╚══════════════════════════════════════╝"

echo ""
echo "─── Project Status ───"
codegraph status 2>/dev/null | grep -E "(Files:|Nodes:|Edges:|Index)"

echo ""
echo "─── Recent Changes ───"
git log --oneline -5

echo ""
echo "─── Affected by last commit ───"
CHANGED=$(git diff --name-only HEAD~1 2>/dev/null || echo "")
if [ -n "$CHANGED" ]; then
    echo "$CHANGED" | head -10
    # Find affected tests
    for f in $(echo "$CHANGED" | grep '\.py$'); do
        codegraph affected "$f" 2>/dev/null | head -5
    done
fi

echo ""
echo "─── Subsystem Dependencies ───"
codegraph query "src/" --kind file 2>/dev/null | wc -l | xargs echo "Tracked source files:"

echo ""
echo "Cognitive anchor complete. Ready for development."
```

---

## 11. 抗漂移机制 (Drift Prevention)

### 11.1 架构漂移检测

```
codegraph 实际依赖图  vs  PROJECT.md §2 子系统架构
        │                       │
        └───────────┬───────────┘
                    │
            不一致检测 (CI 中运行)
                    │
              ┌─────┴─────┐
              │  检测到漂移  │
              └─────┬─────┘
                    │
              触发 Council Phase 审查
              → 决定: 更新文档 OR 修复代码
```

### 11.2 上下文时效检测

| 检测方式 | 说明 |
|----------|------|
| CodeGraph `status` | 检查索引是否过期 (is up to date?) |
| 文件时间戳比较 | CLAUDE.md 最后更新 vs 最近 commit |
| 文档过期标记 | `docs/plans/` 的 `last_verified` Frontmatter |
| CI 检查 | PR 必须更新受影响的文档 |

### 11.3 文档更新触发器

| 触发事件 | 必须更新的文档 |
|----------|---------------|
| 新子系统首次实现 | PROJECT.md + CLAUDE.md |
| 跨子系统接口变更 | PROJECT.md §8 + `src/common/types/` |
| 安全策略变更 | PROJECT.md §3 + `config/safety_params.yaml` |
| 新依赖/工具引入 | CLAUDE.md + PROJECT.md §4 |
| 架构决策 | 新建 `docs/decisions/DR-xxx.md` |
| 每 5 个 PR | Council Phase 审查 → 更新所有过期文档 |

---

## 12. 实践清单

### 每个 Worker Agent 在开始任务前

- [ ] 运行 `scripts/anchor.sh`（认知锚点）
- [ ] 读 `AGENTS.md` + `COUNCIL.md`（工作流规则）
- [ ] 运行 `codegraph context "<我的任务>"`（任务上下文）
- [ ] 运行 `codegraph impact "src/<my_subsystem>/"`（了解影响范围）

### 每个 Worker Agent 在完成任务后

- [ ] 运行 `codegraph affected <changed_files>`（检查测试影响）
- [ ] 运行 `codegraph sync`（更新索引）
- [ ] 检查文档是否需要更新（见 §11.3 触发器）
- [ ] 确保所有测试通过

### parent_agent 在 Phase 审查时

- [ ] 运行 `codegraph sync` + `codegraph status`
- [ ] 运行 `scripts/anchor.sh`
- [ ] 比较 CodeGraph 实际依赖图 vs PROJECT.md
- [ ] 检查所有 `docs/plans/` 的 `last_verified`
- [ ] 更新 CLAUDE.md 中的架构部分（如有变化）
- [ ] 记录漂移到 `docs/decisions/`

---

*本文档是 Vineyard Mower 项目认知保持的基础设施。所有 Agent 应熟悉此文件。*
*版本 1.1.0 — 新增: 工具栈、锚点脚本、抗漂移机制、实践清单*
