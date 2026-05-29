# Vineyard Mower — 自主葡萄园割草机器人

基于 ROS 2 的自主葡萄园割草机器人系统。提供感知、导航、运动控制和任务规划能力，实现结构化葡萄园环境中的无人化割草作业。

## 快速开始

```bash
# 克隆仓库
git clone <repo-url>
cd vineyard_robot

# 安装依赖
# TBD

# 构建
colcon build

# 运行仿真
# TBD
```

## 项目文档

- [Agent 协作规范](./AGENTS.md) — ⚠️ 所有 Agent 必须遵守的工作流规范（含 Plan/Allocate/Implement/Review/Gate 全流程）
- [项目章程](./PROJECT.md) — 架构定义、安全原则、技术约束

## 开发阶段

当前处于 **Phase 1: 仿真验证** 阶段。

## 目录结构

```
vineyard_robot/
├── AGENTS.md               # Agent 协作规范（最高优先级）
├── PROJECT.md               # 项目章程
├── docs/                  # 设计文档
├── src/                   # 源代码
│   ├── perception/        # 感知子系统
│   ├── navigation/        # 导航子系统
│   ├── motion_control/    # 运动控制子系统
│   ├── mission_planner/   # 任务规划器
│   ├── diagnostics/       # 诊断子系统
│   ├── data_pipeline/     # 数据管道
│   └── common/            # 共享库
├── config/                # 配置文件
├── simulation/            # 仿真资源
├── tests/                 # 测试
└── scripts/               # 工具脚本
```
