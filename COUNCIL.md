# COUNCIL.md — LLM Council 审查与监督体系

> **版本**: 1.1.0
> **适用范围**: Vineyard Mower 全部代码变更和设计决策
> **优先级**: 最高（与 AGENTS.md 平级）
> **灵感来源**: LLMcouncil 模式 + Constitutional AI + Multi-Agent Debate

---

## 1. 核心概念

LLM Council（LLM 理事会）是一个**多层次、多视角的 LLM 审查团**。它不是单一审查者，而是一组独立 Agent，各自从不同维度审查同一变更，然后**投票合成结论**。

```
                     ┌─────────────┐
                     │  变更提交     │
                     └──────┬──────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
         ┌────┴────┐  ┌────┴────┐  ┌────┴────┐
         │ 安全守门 │  │ 架构守护 │  │ 质量审计 │
         │  Agent   │  │  Agent   │  │  Agent   │
         └────┬────┘  └────┬────┘  └────┬────┘
              │             │             │
              └─────────────┼─────────────┘
                            │
                    ┌───────┴───────┐
                    │  投票 & 合成   │
                    └───────┬───────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
         ┌────┴────┐  ┌────┴────┐  ┌────┴────┐
         │  PASS   │  │ REVISE  │  │  ABORT  │
         └─────────┘  └─────────┘  └─────────┘
```

### 1.1 与 AGENTS.md 的关系

| 机制 | AGENTS.md Review | COUNCIL.md Council |
|------|-----------------|-------------------|
| 审查者 | 1 个 parent_agent | N 个独立视角 Agent |
| 维度 | A/B/C/D 四维 | 每个维度独立 Agent |
| 判定方式 | 单点判定 | 投票共识 |
| 适用场景 | 日常 Task Review | 设计决策 / 安全变更 / 架构变更 |
| 频率 | 每次 worker 提交 | 关键节点触发 |

### 1.2 触发条件

Council 审查在以下情况**强制触发**：

| 条件 | 理由 |
|------|------|
| 新增/修改 `src/common/types/` | 影响所有子系统接口 |
| 安全关键代码变更 (`motion_control`, `perception`, `navigation`) | 安全关键 |
| 跨子系统接口变更 | 影响集成 |
| 配置文件变更 (`config/*.yaml`) | 影响全局行为 |
| 架构文档变更 | 影响项目方向 |
| 新子系统首次实现 | 架构合规 |
| 每隔 5 个合并的 PR | 周期性全量审查 |

---

## 2. Council 成员

### 2.1 Security Sentinel（安全守门人）

```
视角: 安全第一。任何变更都必须在安全框架内。
宪法: PROJECT.md §3 安全原则
```

**审查清单**:
- [ ] 是否违反任何安全不变量 (§3.1)?
- [ ] 安全事件响应是否正确实现 (§3.2)?
- [ ] 是否绕过了运动控制子系统的确定性验证?
- [ ] 传感器优先原则是否得到遵守?
- [ ] 故障处理是否为显式上报（非静默处理）?
- [ ] 紧急停止路径是否短于 100ms?
- [ ] 是否在无人员检测覆盖区域执行自主操作?

**VETO 权力**: 安全违规 → 一票否决

### 2.2 Architecture Guardian（架构守护人）

```
视角: 架构完整性。代码必须符合定义的系统架构。
宪法: PROJECT.md §2 子系统架构 + §4 技术约束
```

**审查清单**:
- [ ] 是否违反子系统边界（跨子系统直接调用）?
- [ ] 通信是否使用正确的 ROS 2 topic/action/service?
- [ ] 是否有循环依赖?
- [ ] 新代码是否放在正确的子系统目录?
- [ ] 共享类型是否定义在 `src/common/types/`?
- [ ] 是否违反了确定性优先原则?
- [ ] 安全关键决策是否在边缘侧完成（不依赖云端）?

**VETO 权力**: 架构违规 → 一票否决

### 2.3 Quality Auditor（质量审计人）

```
视角: 代码质量、可维护性、测试覆盖。
宪法: 编码规范 + 测试要求
```

**审查清单**:
- [ ] 测试覆盖率是否充分（安全关键 ≥ 90%, 运行关键 ≥ 80%, 非关键 ≥ 60%）?
- [ ] 所有测试是否通过?
- [ ] 是否有代码异味（重复、过长函数、过多参数）?
- [ ] 公共 API 是否有文档?
- [ ] 错误处理是否完善?
- [ ] 是否有明显的性能问题?

**VETO 权力**: 无（仅建议），但安全关键代码测试不足 → 升级为否决

### 2.4 Integration Coordinator（集成协调人）

```
视角: 跨子系统接口一致性。变更后各子系统能否正确协作。
宪法: PROJECT.md §8 通信与接口规范
```

**审查清单**:
- [ ] 消息类型变更是否向后兼容?
- [ ] 是否通知了所有受影响的子系统 Agent?
- [ ] 接口变更是否更新了文档?
- [ ] 集成测试是否通过?
- [ ] 是否有 breaking change 未记录?

**VETO 权力**: Breaking change 未协调 → 一票否决

---

## 3. 投票规则

### 3.1 权重系统

| Council 成员 | 权重 | 否决权 | 
|-------------|------|--------|
| Security Sentinel | 3 | ✅ |
| Architecture Guardian | 3 | ✅ |
| Quality Auditor | 1 | 仅测试不足时 |
| Integration Coordinator | 2 | ✅ (breaking change) |

### 3.2 判定规则

```
PASS:   总赞成 ≥ 6 且无否决票
REVISE: 总赞成 ≥ 4 且有具体修改意见
ABORT:  任一否决票触发 OR 总赞成 < 4
```

### 3.3 辩论机制

当 Council 成员意见分歧时：

1. **分歧检测**: 两个及以上成员结论相反
2. **辩论轮**: 各成员用一句话阐述核心关切
3. **parent_agent 裁决**: 在安全/架构分歧中，parent_agent 审查双方论点并做出最终判定
4. **分歧记录**: 所有分歧及裁决记录到 `docs/decisions/` 决策日志

---

## 4. 周期性监督（对齐审查）

### 4.1 节奏

| 频率 | 审查范围 | 执行者 |
|------|----------|--------|
| **每 PR** | 变更文件 | Single Reviewer (parent_agent) |
| **每 5 PRs** | 变更子系统 | Council (4 成员) |
| **每 Phase** | 全项目架构对齐 | Full Council + All Worker Agents |
| **每月** | 安全审计 | Security Sentinel singlular |

### 4.2 Phase 审查（架构对齐检查）

在每个开发阶段结束时执行：

1. **代码 vs 文档 比对**: 使用 CodeGraph 对比实际代码结构与 PROJECT.md 描述的架构
2. **依赖图验证**: 检查实际依赖关系是否符合设计的子系统划分
3. **接口合规**: 验证所有跨子系统通信是否使用定义的消息类型
4. **安全路径审计**: 端到端审查安全关键数据流是否完整
5. **技术债务记录**: 记录偏离设计的部分，列入 `docs/decisions/`

---

## 5. 决策日志

所有 Council 判定和设计决策记录在：

```
docs/decisions/
├── INDEX.md                 # 决策索引
├── DR-001-template.md       # 决策记录模板
├── DR-001-xxx.md            # 具体决策
└── ...
```

### 决策记录模板

```markdown
# DR-{序号}: {标题}

- **日期**: YYYY-MM-DD
- **状态**: 提议 / 接受 / 废弃 / 替代
- **背景**: 为什么需要做这个决定
- **决策**: 做了什么决定
- **选项**: 考虑过的其他方案
- **后果**: 正面和负面影响
- **Council 投票**: Security: ✅ | Architecture: ✅ | Quality: ✅ | Integration: ✅
- **相关**: DR-xxx, PR-xxx
```

---

## 6. 集成到工作流

### 6.1 修改后的执行协议

```
Plan → Decompose → Dispatch → Implement → Review → Gate
                                              │
                                     ┌────────┴────────┐
                                     │  Council 触发?   │
                                     │  安全/架构/接口?  │
                                     └────────┬────────┘
                                        ┌─────┴─────┐
                                        │   是       │ 否
                                        ▼           ▼
                                   Council      Single
                                   审查          Review
                                        │           │
                                        └─────┬─────┘
                                              ▼
                                            Gate
```

### 6.2 Council 调用方式

```
# 通过 Agent 工具并行调用 Council 成员
parallel([
    () => agent(security_sentinel_prompt, {schema: VERDICT}),
    () => agent(architecture_guardian_prompt, {schema: VERDICT}),
    () => agent(quality_auditor_prompt, {schema: VERDICT}),
    () => agent(integration_coordinator_prompt, {schema: VERDICT}),
]).then(verdicts => synthesize(verdicts))
```

### 6.3 Council Verdict Schema

```json
{
  "verdict": "PASS" | "REVISE" | "ABORT",
  "concerns": ["具体关切列表"],
  "suggestions": ["改进建议"],
  "veto": false,
  "confidence": 0.0 - 1.0
}
```

---

## 7. 特殊规则

- **Security Sentinel** 的意见在安全关键代码上为 VETO，不可被 parent_agent 否决
- **Architecture Guardian** 在架构违规上的 VETO 可由 parent_agent 覆盖，但必须记录决策
- Council 成员使用与 Worker Agent 相同的文件边界限制
- Council 成员只读，不写代码
- 所有 Council 判定公开透明，记录在 Git 历史中

---

## 8. 宪法原则 (Constitutional Principles)

> 灵感来源: Anthropic Constitutional AI (Bai et al., 2022) + AI Safety via Debate (Irving et al., 2018)

Council 所有审查均以此宪法为最高准则。每一条原则都是可验证、可度量的。

### 8.1 安全宪法

```
S1: 所有物理执行指令必须经运动控制子系统确定性验证
S2: 传感器数据与规划路径冲突时，传感器数据为准（world is ground truth）
S3: 急停路径响应时间 ≤ 100ms，不可被任何异步操作绕过
S4: 禁止在人员检测未覆盖区域执行自主操作
S5: 故障必须显式上报，禁止静默降级处理
S6: 安全关键决策必须在边缘侧完成，不依赖云端
```

### 8.2 架构宪法

```
A1: 子系统间只能通过 ROS 2 topic/service/action 通信
A2: 共享类型必须定义在 src/common/types/，不可侵入其他子系统
A3: 高不确定性的指令 → 停止并请求操作员确认 (无猜测执行)
A4: 低层控制路径必须确定性执行，不可依赖概率输出
A5: 每个子系统暴露诊断接口 (可观测性)
A6: 循环依赖为非法；依赖图必须是有向无环图 (DAG)
```

### 8.3 质量宪法

```
Q1: 安全关键代码测试覆盖率 ≥ 90%
Q2: 运行关键代码测试覆盖率 ≥ 80%
Q3: 非关键代码测试覆盖率 ≥ 60%
Q4: 公共 API 必须有 docstring 或 Doxygen 注释
Q5: 每个 PR 必须有对应的测试新增/修改
```

### 8.4 宪法使用

Council 成员在审查时**必须引用宪法条款**。判定格式：

```
S1 ✅ 通过 — 运动控制节点在所有执行路径上调用 SafetyLimits
S5 ❌ 违规 — 传感器错误在 _process_scan() 中静默返回 None，未上报
A3 ✅ 通过 — 低置信度检测结果正确触发了操作员确认请求
```

---

## 9. 分层审查模型 (Hierarchical Escalation)

> 灵感来源: 研究论文中 tiered review 模式 — 便宜模型过滤常规问题，昂贵模型深度审查高信号变更

不是每个变更都需要全 Council。分层审查在效率和安全性之间取得平衡。

### 9.1 分层结构

```
                    变更提交
                        │
               ┌────────┴────────┐
               │   Tier 1 (自动)  │  ← 快速/低成本
               │   lint + 测试    │     每个 PR 都跑
               │   + 类型检查     │
               └────────┬────────┘
                        │
               ┌────────┴────────┐
               │   Tier 2 (半自动)│  ← 中等成本
               │   parent_agent   │     每个 PR 都跑
               │   Single Review  │
               └────────┬────────┘
                        │
               ┌────────┴────────┐
               │   Tier 3 (Council)│ ← 高成本
               │   4 成员全审查   │     触发条件触发
               │   (安全/架构变更) │
               └────────┬────────┘
                        │
               ┌────────┴────────┐
               │   Tier 4 (对抗)  │  ← 最高成本
               │   红队攻击审查   │     安全关键变更
               └─────────────────┘
```

### 9.2 升级条件

| 从 | 到 | 触发条件 |
|----|----|----------|
| Tier 1 | Tier 2 | 测试通过 + lint 通过（自动进入） |
| Tier 2 | Tier 3 | 满足 §1.2 触发条件 |
| Tier 3 | Tier 4 | 安全关键代码 + Council 任一人投 ABORT |
| Tier 3 | Human | 两人投 ABORT 且无法达成共识 |

---

## 10. 对抗审查模式 (Adversarial Review)

> 灵感来源: Red-team/Blue-team + AI Safety via Debate

对于**安全关键变更**，在 Tier 3 之后增加对抗审查：

```
红队 (攻击者): "你是这个变更的敌人。找出所有可能失败的方式。
             假设最坏情况，构造边缘案例，尝试绕过安全机制。"
             → 输出: 攻击向量列表

蓝队 (防御者): "反驳红队的每个攻击向量。证明安全机制能拦截攻击，
             或承认无法防御并建议修复。"
             → 输出: 防御评估

绿队 (裁判):   "评估红蓝双方的论点。无法被有效防御的攻击向量
             → 必须修复后才能通过 Council。"
             → 输出: 最终对抗审查报告
```

### 10.1 对抗审查触发条件

- 任何涉及 `src/motion_control/safety_limits.py` 的变更
- 任何修改急停逻辑的变更
- 任何新增的物理执行路径（电机、舵机、刀盘）
- Phase 审查中的安全路径审计

---

## 11. 模型多样性原则 (Model Diversity)

> 灵感来源: 研究确认 — 不同模型家族的组合可以显著降低关联错误率 (correlated errors)

### 11.1 多样性维度

| 维度 | 选择 A | 选择 B |
|------|--------|--------|
| 模型家族 | Claude | GPT / Gemini / DeepSeek |
| 温度 | temperature=0 (确定性) | temperature=0.3 (探索性) |
| Prompt 风格 | 结构化 rubric | 开放式 reasoning |
| 角色视角 | 正面评估 (找正确) | 负面评估 (找错误) |

### 11.2 应用策略

- **Tier 2 (parent_agent)**: 单一模型，确定性审查
- **Tier 3 (Council)**: 至少 2 个模型家族（如 Claude + DeepSeek），防止共享盲区
- **Tier 4 (Adversarial)**: 红队和蓝队使用不同模型，绿队使用第三个模型
- **不要**让 Council 成员在独立审查前看到彼此的意见 — 防止 early convergence (群体思维)

---

## 12. 结构化审查输出 Schema

> 每个 Council 成员的输出必须是结构化 JSON，便于程序化聚合

```json
{
  "reviewer": "Security Sentinel",
  "model": "claude-opus-4-8",
  "timestamp": "2026-05-29T14:00:00Z",
  "verdict": "PASS",
  "confidence": 0.92,
  "constitution_checks": [
    {"id": "S1", "status": "PASS", "evidence": "所有电机指令经过 SafetyLimits.clamp_velocity()", "file": "src/motion_control/motion_controller.py:103"},
    {"id": "S2", "status": "PASS", "evidence": "传感器优先级正确: 融合数据 > 规划数据"},
    {"id": "S5", "status": "FAIL", "evidence": "_handle_lidar_error() 静默返回空列表", "file": "src/perception/lidar.py:87"}
  ],
  "concerns": [
    {"severity": "HIGH", "description": "传感器故障未显式上报", "ref": "S5"}
  ],
  "suggestions": [
    {"action": "ADD", "description": "在 _handle_lidar_error() 中发布诊断消息并记录错误日志", "file": "src/perception/lidar.py:87"}
  ],
  "veto": false,
  "notes": "整体安全设计良好，仅一处上报问题需修复"
}
```

---

## 13. 与 LLMcouncil 研究论文的对照

| 论文/技术 | 我们的实现 |
|-----------|-----------|
| Constitutional AI (Anthropic, 2022) | §8 宪法原则 — 所有审查依宪法进行 |
| Multiagent Debate (Du et al., 2023) | §3.3 辩论机制 — 分歧时成员互辩 |
| AI Safety via Debate (Irving et al., 2018) | §10 对抗审查 — 红蓝绿三方对抗 |
| Self-Consistency (Wang et al., 2023) | §3.2 投票规则 — 多票共识 |
| Tiered Review (practical pattern) | §9 分层审查 — 四级升级 |
| Role-based Council (LLMcouncil Python) | §2 四成员 — 安全/架构/质量/集成 |

---

*本文档是 Vineyard Mower 项目的审查与监督体系基础。与 AGENTS.md 配合使用。*
*版本 1.1.0 — 新增: 宪法原则、分层审查、对抗审查、模型多样性、结构化输出*
