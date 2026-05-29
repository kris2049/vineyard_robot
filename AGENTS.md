# AGENTS.md — Vineyard Mower Multi-Agent Kanban System

> **版本**: 4.0.0
> **适用范围**: Hermes Orchestrator + 6 Kanban Worker Profiles
> **优先级**: 最高
> **实现方式**: Hermes Kanban (`kanban_create` / `kanban_complete` / `kanban_block`)

---

## 1. Agent Profile 体系

| Profile | 角色 | SOUL.md | 子系统目录 | 安全等级 |
|---------|------|---------|-----------|----------|
| `parent_agent` | 编排者 (Orchestrator) | `~/.hermes/profiles/parent_agent/SOUL.md` | 全部（只读审查） | — |
| `motion-control` | 运动控制 Worker | `~/.hermes/profiles/motion-control/SOUL.md` | `src/motion_control/` | ⚠️ 安全关键 |
| `perception` | 感知 Worker | `~/.hermes/profiles/perception/SOUL.md` | `src/perception/` | ⚠️ 安全关键 |
| `navigation` | 导航 Worker | `~/.hermes/profiles/navigation/SOUL.md` | `src/navigation/` | ⚠️ 安全关键 |
| `mission-planner` | 任务规划 Worker | `~/.hermes/profiles/mission-planner/SOUL.md` | `src/mission_planner/` | 🔶 运行关键 |
| `diagnostics` | 诊断 Worker | `~/.hermes/profiles/diagnostics/SOUL.md` | `src/diagnostics/` | 🔶 运行关键 |
| `data-pipeline` | 数据管道 Worker | `~/.hermes/profiles/data-pipeline/SOUL.md` | `src/data_pipeline/` | 🔵 非关键 |

每个 Worker Profile 的 SOUL.md 定义了其身份、子系统职责、编码规范、文件边界。

---

## 2. 执行协议：Plan → Decompose → Dispatch → Review → Gate

```
┌────────┐   ┌───────────┐   ┌───────────┐   ┌──────────┐   ┌────────┐
│  Plan  │ → │ Decompose │ → │ Dispatch  │ → │  Review  │ → │  Gate  │
│parent_ │   │ parent_   │   │ kanban_   │   │ parent_  │   │parent_ │
│ agent  │   │ agent     │   │ create    │   │ agent    │   │ agent  │
└────────┘   └───────────┘   └───────────┘   └──────────┘   └────────┘
                                   │
                                   ▼
                          ┌─────────────────┐
                          │  Kanban Worker   │
                          │  (独立 Process)  │
                          │  持久化·重启不丢  │
                          └─────────────────┘
```

| 阶段 | 执行者 | 工具 |
|------|--------|------|
| **Plan** | parent_agent | 编写 `docs/plans/` |
| **Decompose** | parent_agent | 拆分为 Task，画依赖图 |
| **Dispatch** | parent_agent | `kanban_create(assignee=<profile>)` |
| **Implement** | Worker Profile | 自治执行，heartbeat 汇报 |
| **Review** | parent_agent | 对照 PROJECT.md + 运行测试 |
| **Gate** | parent_agent | PASS / REVISION (kanban_block) / ABORT |

---

## 3. Plan 阶段（parent_agent）

计划模板见 [docs/plans/](../docs/plans/) 目录。每个计划必须指定每个 Task 分配给哪个 Worker Profile。

---

## 4. Dispatch 阶段（parent_agent）

```python
# 创建 Kanban 任务
task = kanban_create(
    title="motion-control: 实现差速运动学模块",
    assignee="motion-control",
    body="""
## TASK
实现 DifferentialDrive 类的 forward() 方法...

## FILES
- Create: src/motion_control/kinematics.py
- Create: tests/unit/test_kinematics.py

## VERIFICATION
python3 -m pytest tests/unit/test_kinematics.py -v
""",
)

# 有依赖关系时使用 parents
task2 = kanban_create(
    title="motion-control: 实现运动控制节点",
    assignee="motion-control",
    parents=[task1_id],  # 等 T1 完成后才调度
    body="...",
)
```

### 依赖图示例

```
T1: 运动学模块 (motion-control) ──→ T3: 控制节点 (motion-control)
                                           │
T2: 键盘遥操作 (motion-control) ──────────┘ (T1 和 T2 可并行)
```

---

## 5. Implement 阶段（Worker Profile）

Worker 自治执行。必须：

- 读取 AGENTS.md + PROJECT.md + 自己的 SOUL.md
- 严格按照文件边界操作
- 定期 heartbeat 汇报进度
- 完成后 `kanban_complete(summary=..., metadata={tests: ...})`
- 需人工审查时 `kanban_block(reason="review-required: ...")`

### Worker 完成格式

```python
kanban_complete(
    summary="实现差速运动学: DifferentialDrive + WheelVelocity, 5/5 tests pass",
    metadata={
        "changed_files": ["src/motion_control/kinematics.py", "tests/unit/test_kinematics.py"],
        "tests_run": 5,
        "tests_passed": 5,
    },
)
```

---

## 6. Review 阶段（parent_agent）

### 6.1 审查维度

| 维度 | 对照 | 性质 |
|------|------|------|
| A: 安全 | PROJECT.md §3 | ⚠️ 硬关卡 |
| B: 架构 | PROJECT.md §2 | ⚠️ 硬关卡 |
| C: 计划 | Plan 文档 | ⚠️ 硬关卡 |
| D: 质量 | 编码规范 | 软关卡 |

### 6.2 审查方法（强制执行）

```
1. git diff 查看变更
2. 对照 PROJECT.md 检查 A/B 维度
3. 对照 Plan 检查 C 维度
4. 阅读代码检查 D 维度
5. ⚠️ python3 -m pytest tests/ -v （强制执行）
6. 判定 PASS / REVISION / ABORT
```

---

## 7. Gate 阶段（parent_agent）

| 判定 | 条件 | 行为 |
|------|------|------|
| **PASS** | 四维通过 + 测试全绿 | 接受，进入下一 Task |
| **REVISION** | 可修复问题 | `kanban_block(reason="revision-required: ...")` 驳回 |
| **ABORT** | 安全违规 / 不可恢复 | 停止，上报用户 |

---

## 8. Worker 文件边界

| Worker Profile | 允许目录 | 禁止 |
|---------------|---------|------|
| `motion-control` | `src/motion_control/`, `src/common/types/`, `tests/`, `simulation/models/vineyard_mower/` | 其他 src/ |
| `perception` | `src/perception/`, `src/common/types/`, `tests/`, `simulation/models/vineyard_mower/` (sensor 部分) | 其他 src/ |
| `navigation` | `src/navigation/`, `src/common/types/`, `tests/` | 其他 src/ |
| `mission-planner` | `src/mission_planner/`, `src/common/types/`, `tests/`, `simulation/worlds/` | 其他 src/ |
| `diagnostics` | `src/diagnostics/`, `src/common/types/`, `tests/` | 其他 src/ |
| `data-pipeline` | `src/data_pipeline/`, `src/common/types/`, `tests/` | 其他 src/ |

所有 Worker 禁止修改：`AGENTS.md`, `PROJECT.md`, `config/*.yaml`, `docs/`。

---

## 9. 并行规则

- 操作不同文件 → 可并行 dispatch
- 共享 `src/common/types/` → 顺序执行，注明先后
- 有数据依赖 → 使用 `parents=[...]` 链

---

## 10. 特殊规则

- `config/*.yaml` 由 parent_agent 直接修改
- parent_agent 禁止写 `src/` 代码
- parent_agent Review 必须跑全量测试
- 安全关键 Worker 的 Task 粒度 ≤ 50 行核心逻辑

---

## 11. 启动检查清单

### parent_agent
- [ ] 读取 AGENTS.md + PROJECT.md
- [ ] 读取自己的 SOUL.md
- [ ] 确认所有 Worker Profile 存在 (`hermes profile list`)
- [ ] 读取最新 `docs/plans/`

### Worker Profile
- [ ] 读取 AGENTS.md + PROJECT.md
- [ ] 读取自己的 SOUL.md
- [ ] 确认文件边界
- [ ] `kanban_show` 检查任务状态

---

*本文件是项目 Agent 协作最高规范。所有 Profile 必须遵守。*
