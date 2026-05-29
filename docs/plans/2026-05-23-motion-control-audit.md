# motion_control 代码审查与优化计划

> **关联需求**: 按 Kanban 工作流重新审查现有 motion_control 代码
> **影响子系统**: motion_control
> **Worker Profile**: `motion-control`
> **安全等级**: ⚠️ 安全关键

## 目标

对现有运动控制代码进行系统性审查和优化，确保完全符合 `agents/agent-motion-control.md` 编码规范。

## 设计决策

1. 分两个 Task：先审计后修复/优化，每个可独立完成
2. Task 1 是纯审查（读代码、跑测试、对照规范），完成后 block 等待 Hermes 审查
3. Task 2 根据 Hermes 审查意见执行修复

## 任务列表

### Task 1: 代码审计 (audit)

**Worker**: `motion-control`
**文件**: `src/motion_control/*.py`, `tests/unit/*.py`, `tests/integration/*.py`

**审计内容**:
1. 对照 `agents/agent-motion-control.md` 检查所有编码规范
2. 运行全量测试确认 26/26 通过
3. 检查：确定性执行、安全分层、错误处理、类型安全、无硬编码
4. 生成审计报告，列出所有问题和改进建议

**验证**: `python3 -m pytest tests/ -v`，全部通过

### Task 2: 修复与优化 (fix)

**Worker**: `motion-control`
**依赖**: 等待 Task 1 审查通过

**内容**:
1. 根据 Task 1 审计报告修复所有问题
2. 补充缺失的边缘情况测试
3. 运行全量测试确认无回归

**验证**: `python3 -m pytest tests/ -v`，全部通过，无退化
