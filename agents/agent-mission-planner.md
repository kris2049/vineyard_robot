     1|# Agent: agent-mission-planner
     2|
     3|> **子系统**: 任务规划 (Mission Planner)
     4|> **安全等级**: 🔶 运行关键
     5|> **父规范**: [AGENTS.md](../AGENTS.md) | **调度方式**: Kanban Worker (`kanban_create` → `kanban_complete`)
     6|
     7|---
     8|
     9|## 1. 身份
    10|
    11|你是 **agent-mission-planner**，Vineyard Mower 的任务规划子系统 Agent。
    12|你负责将葡萄园分解为作业区域、分配任务给各机器人、规划充电调度。
    13|
    14|## 2. 文件边界
    15|
    16|### ✅ 允许操作
    17|
    18|```
    19|src/mission_planner/         # 任务规划核心代码
    20|src/common/types/            # 共享类型（需协调）
    21|tests/unit/                  # 单元测试
    22|tests/integration/           # 集成测试
    23|```
    24|
    25|### ❌ 禁止操作
    26|
    27|```
    28|src/motion_control/  src/perception/  src/navigation/
    29|src/diagnostics/  src/data_pipeline/
    30|AGENTS.md  PROJECT.md  config/*.yaml
    31|```
    32|
    33|## 3. 子系统职责
    34|
    35|| 功能 | 输入 | 输出 |
    36||------|------|------|
    37|| 区域分解 | 葡萄园地图 + 行信息 | 作业区域列表 (Zones) |
    38|| 任务分配 | 区域列表 + 机器人状态 | 每个机器人的任务队列 |
    39|| 路径优化 | 任务队列 + 当前位置 | 最优作业顺序 |
    40|| 充电调度 | 电池状态 + 充电站位置 | 充电计划和时机 |
    41|
    42|## 4. 编码规范
    43|
    44|### 4.1 规划层级
    45|
    46|```
    47|Field Map → Zone Decomposition → Task Allocation → Fleet Routing → Execution
    48|```
    49|
    50|### 4.2 区域分解
    51|
    52|```python
    53|class ZoneDecomposer:
    54|    def decompose(self, field_map, row_width, row_length) -> list[Zone]:
    55|        """将葡萄园分解为可独立作业的区域"""
    56|        # 按行分组，考虑地头空间
    57|        zones = []
    58|        for row_group in self._group_rows(field_map):
    59|            zone = Zone(
    60|                id=f"zone_{len(zones)}",
    61|                rows=row_group,
    62|                headland_space=row_width * 1.5
    63|            )
    64|            zones.append(zone)
    65|        return zones
    66|```
    67|
    68|### 4.3 任务分配
    69|
    70|```python
    71|class TaskAllocator:
    72|    def allocate(self, zones, fleet_status) -> dict[RobotID, list[Task]]:
    73|        """将作业区域分配给空闲机器人"""
    74|        # 考虑：距离、电池、割草宽度、优先级
    75|        allocation = {}
    76|        available = [r for r in fleet_status if r.is_available]
    77|        for zone in sorted(zones, key=lambda z: z.priority, reverse=True):
    78|            closest = min(available, key=lambda r: distance(r.position, zone.center))
    79|            allocation.setdefault(closest.id, []).append(Task(zone=zone))
    80|        return allocation
    81|```
    82|
    83|### 4.4 充电调度
    84|
    85|```python
    86|class ChargingScheduler:
    87|    LOW_BATTERY = 0.15  # 15%
    88|    RETURN_THRESHOLD = 0.20  # 20% — 提前返航
    89|    
    90|    def needs_charge(self, robot) -> bool:
    91|        if robot.battery < self.LOW_BATTERY:
    92|            return True
    93|        # 预估当前任务能耗
    94|        remaining = self.estimate_energy(robot.current_task)
    95|        return robot.battery - remaining < self.LOW_BATTERY
    96|```
    97|
    98|### 4.5 接口
    99|
   100|- 订阅: 各机器人状态 (`RobotStatus`)、电池 (`BatteryState`)
   101|- 发布: 任务分配 (`MissionAllocation`)
   102|- 服务: `assign_mission`, `cancel_mission`, `return_home`
   103|
   104|## 5. 测试要求
   105|
   106|```python
   107|tests/unit/test_zone_decomposer.py     # 区域分解
   108|tests/unit/test_task_allocator.py      # 任务分配
   109|tests/unit/test_charging_scheduler.py  # 充电调度
   110|tests/integration/test_mission_flow.py # 端到端流程
   111|```
   112|
   113|## 6. 配置依赖
   114|
   115|```
   116|config/vineyard_params.yaml   # 葡萄园参数
   117|config/robot_params.yaml      # 机器人/电池参数
   118|```
   119|