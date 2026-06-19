# AGENTS.md — Vineyard Mower Multi-Agent Workflow

> **版本**: 5.0.0
> **适用范围**: Claude Code 多 Agent 协作
> **优先级**: 最高 — 所有 Agent 必须遵守
> **最后更新**: 2026-06-19

---

## 1. 角色体系

Vineyard Mower 项目采用**三角色分工**，角色不可兼任：

| 角色 | 标识 | 核心职责 | 写代码 | 审查 | Git |
|------|------|----------|--------|------|-----|
| **parent_agent** | 当前会话的主 agent | 开发基础设施 + 版本管理 + 最终 Gate | ❌ | Gate | ✅ |
| **architect** | 自定义 agent (/architect) | 架构设计 + 技术决策 + Worker 审查 | ❌ | 深度审查 | ❌ |
| **Worker** | 按需创建的子 agent | 实现业务代码 | ✅ | ❌ | ❌ |

### 1.1 parent_agent（编排者）

- 维护开发基础设施（审查系统、代码质量工具、CI）
- 管理 Git 版本控制（创建仓库、提交、推送、分支）
- 执行最终 Gate 判定（PASS / REVISE / ABORT）
- 审查 architect 提交的设计方案和决策记录
- 维护本文件（AGENTS.md）、PROJECT.md、COUNCIL.md、CLAUDE.md、config/*.yaml
- **禁止**编写 src/ 业务代码

### 1.2 architect（系统架构师）

- 设计业务系统架构
- 技术方案选型与决策
- 编写实现计划 docs/plans/ 和架构决策记录 docs/decisions/
- 审查 Worker 代码（架构维度、安全维度、质量维度）
- 触发 LLM Council 深度审查（按 COUNCIL.md 条件）
- 提交设计/审查结论给 parent_agent 做最终 Gate
- **禁止**编写 src/ 业务代码
- **禁止**操作 Git

### 1.3 Worker（编码实现者）

- 在文件边界内实现业务代码
- 确保测试覆盖达标
- 完成编码后通知 architect 审查
- **禁止**跨子系统目录写代码
- **禁止**修改 AGENTS.md / PROJECT.md / COUNCIL.md / CLAUDE.md / config/*.yaml
- **禁止**操作 Git

---

## 2. 执行协议

### Phase 1: 设计

```
你 (用户) <--> architect -- 讨论技术方案
     architect -- 输出 docs/plans/<计划文档>
     architect -- 输出 docs/decisions/<决策记录>
          |
          v
     parent_agent -- Gate: 设计方案审查
          |
       +--+--+
       |PASS | REVISE -> 退回 architect 修改
       |     |
       v     v
    进入Phase2 返回修改
```

### Phase 2: 实现与审查

```
architect -- 拆解 Task -> Dispatch Worker
     |
     v
Worker -- 实现代码 -> 通知 architect
     |
     v
architect -- 审查 Worker 代码
  |-- Tier 1: 自动 (lint + test)
  |-- Tier 2: 架构审查（架构/安全/质量）
  +-- Tier 3: Council 触发? -> 4 成员并行审查
     |
     v
parent_agent -- 最终 Gate
     |
   +--+--+
   |PASS | REVISE -> 退回
   |     |
   v     v
 提交   驳回
```

### Phase 3: 版本管理

```
parent_agent -- git add + git commit + git push
     |
     v
你 (用户) -- 确认 / 打 tag / 部署
```

---

## 3. 文件边界

### 3.1 按角色

| 角色 | 允许写入 | 禁止写入 |
|------|----------|----------|
| parent_agent | `.claude/`, `config/*.yaml`, `scripts/`, AGENTS.md, PROJECT.md, COUNCIL.md, CLAUDE.md, 任意 | `src/` 业务代码 |
| architect | `docs/plans/`, `docs/decisions/`, `agents/` | `src/`, `config/`, AGENTS.md, PROJECT.md, COUNCIL.md, CLAUDE.md |
| Worker | 归属子系统目录 (见 3.2) | 其他子系统, 根级文档, config |

### 3.2 Worker 文件边界

| Worker | 允许目录 | 禁止 |
|--------|----------|------|
| motion-control | `src/motion_control/`, `src/common/types/`, `tests/` | 其他 src/ |
| perception | `src/perception/`, `src/common/types/`, `tests/` | 其他 src/ |
| navigation | `src/navigation/`, `src/common/types/`, `tests/` | 其他 src/ |
| mission-planner | `src/mission_planner/`, `src/common/types/`, `tests/` | 其他 src/ |
| diagnostics | `src/diagnostics/`, `src/common/types/`, `tests/` | 其他 src/ |
| data-pipeline | `src/data_pipeline/`, `src/common/types/`, `tests/` | 其他 src/ |

---

## 4. 审查体系

### 4.1 分层审查模型 (Tiered Review)

```
变更提交
    |
Tier 1 (自动) --- ruff lint + pytest         <- 每次必跑
    |
Tier 2 --- architect 架构审查                <- 每次必跑
    |        |-- 架构合规 (PROJECT.md 2)
    |        |-- 安全合规 (PROJECT.md 3 + 安全宪法)
    |        |-- 计划对齐 (对应 docs/plans/)
    |        +-- 质量要求 (测试 + 编码规范)
    |
Tier 3 --- LLM Council 4 成员并行审查        <- 条件触发
    |        条件: 安全代码 / 跨接口 / 每5次
    |
Tier 4 --- 对抗审查 (红队->蓝队->裁判)       <- 安全关键变更
    |
    v
parent_agent Gate -> git commit
```

### 4.2 触发条件

| Tier | 触发条件 | 执行者 |
|------|----------|--------|
| 1 | 每次 Worker 提交 | 自动化脚本 |
| 2 | 每次 Worker 提交 | architect |
| 3 | 安全关键代码 / `src/common/types/` 变更 / 跨接口变更 / 每5次提交 | architect -> parallel(Council) |
| 4 | `src/motion_control/safety_limits.py` / 急停逻辑 / 新物理执行路径 | architect -> 对抗审查 |

### 4.3 LLM Council 成员

| 成员 | 视角 | 否决权 |
|------|------|--------|
| Security Sentinel | 安全不变量、急停路径、人员检测 | 一票否决 |
| Architecture Guardian | 子系统边界、依赖图、接口规范 | 可被 parent_agent 覆盖 |
| Quality Auditor | 测试覆盖率、代码质量 | 仅测试不足时 |
| Integration Coordinator | 跨子系统接口兼容性 | breaking change 否决 |

---

## 5. 角色启动检查清单

### 5.1 parent_agent 启动

- [ ] 读取 CLAUDE.md -- 项目上下文
- [ ] 读取 AGENTS.md -- 协作流程（本文档）
- [ ] 读取 PROJECT.md -- 架构约束
- [ ] 读取 COUNCIL.md -- 审查规范
- [ ] `git log --oneline -5` -- 最近变更
- [ ] `ls docs/plans/` -- 当前计划
- [ ] 运行 `./scripts/anchor.sh`

### 5.2 architect 启动 (/architect)

- [ ] 读取 PROJECT.md -- 系统架构
- [ ] 读取 AGENTS.md -- 协作流程
- [ ] 读取 COUNCIL.md -- 审查规范
- [ ] 读取 KNOWLEDGE.md -- 知识管理
- [ ] 读取 `docs/plans/` -- 当前计划
- [ ] 读取 `docs/decisions/` -- 已有决策

### 5.3 Worker 启动

- [ ] 读取 PROJECT.md -- 理解系统架构
- [ ] 读取 AGENTS.md 3.2 -- 确认自己的文件边界
- [ ] 读取归属子系统 agents/agent-<name>.md -- 编码规范
- [ ] 确认测试框架可用: `python3 -m pytest --version`

---

## 6. 禁止规则

违反以下任何一条立即 ABORT：

1. parent_agent 不得写入 src/ 业务代码
2. architect 不得写入 src/ 业务代码
3. architect 不得操作 Git
4. Worker 不得写入非归属目录
5. Worker 不得修改 AGENTS.md / PROJECT.md / COUNCIL.md / CLAUDE.md / config/*.yaml
6. 不得跳过审查直接提交代码
7. 安全关键代码不得在没有测试覆盖的情况下提交
8. 任何角色不得在未读取本文档的情况下执行任务

---

## 7. 紧急覆写

在以下情况下可破例操作，但必须在 commit message 中注明理由，并在 docs/decisions/ 新增决策记录：

- 安全漏洞需要立即修复
- 项目基础设施故障
- 用户明确指示

---

*本文件是 Vineyard Mower 项目多 Agent 协作的最高规范。所有 Agent 必须遵守。*
*违反本文件规定的行为将被 ABORT。*
