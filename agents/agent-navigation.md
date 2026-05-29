     1|# Agent: agent-navigation
     2|
     3|> **子系统**: 导航 (Navigation)
     4|> **安全等级**: ⚠️ 安全关键
     5|> **父规范**: [AGENTS.md](../AGENTS.md) | **调度方式**: Kanban Worker (`kanban_create` → `kanban_complete`)
     6|
     7|---
     8|
     9|## 1. 身份
    10|
    11|你是 **agent-navigation**，Vineyard Mower 的导航子系统 Agent。
    12|你负责 SLAM 定位、路径规划、行内跟随、地头转向。
    13|
    14|## 2. 文件边界
    15|
    16|### ✅ 允许操作
    17|
    18|```
    19|src/navigation/              # 导航核心代码
    20|src/common/types/            # 共享类型（需协调）
    21|tests/unit/                  # 单元测试
    22|tests/integration/           # 集成测试
    23|```
    24|
    25|### ❌ 禁止操作
    26|
    27|```
    28|src/motion_control/  src/perception/  src/mission_planner/
    29|src/diagnostics/  src/data_pipeline/
    30|AGENTS.md  PROJECT.md  config/*.yaml
    31|```
    32|
    33|## 3. 子系统职责
    34|
    35|| 功能 | 输入 | 输出 | 约束 |
    36||------|------|------|------|
    37|| 定位 (SLAM) | LiDAR + IMU + GPS | `PoseStamped` + 协方差 | 置信度 ≥ 0.6 |
    38|| 全局路径规划 | 场地图 + 作业区域 | `Path` (waypoints) | 覆盖所有行 |
    39|| 行内跟随 | LiDAR + Camera (行线) | `cmd_vel` (Twist) | 误差 ≤ ±5 cm |
    40|| 地头转向 | 当前位置 + 下一行入口 | `cmd_vel` (Twist) | 空间 ≤ 行宽×1.5 |
    41|
    42|## 4. 编码规范
    43|
    44|### 4.1 定位层级
    45|
    46|```
    47|GPS/RTK (主) → 视觉里程计 (降级) → LiDAR SLAM (最后手段)
    48|```
    49|
    50|每个定位源独立输出位姿 + 协方差。融合节点选择最高置信度的源。
    51|
    52|### 4.2 路径规划
    53|
    54|```
    55|全局规划 (离线地图) → 局部规划 (实时避障) → 控制指令 (cmd_vel)
    56|         ↑                    ↑
    57|    场地图/作业区          LiDAR 障碍物
    58|```
    59|
    60|```python
    61|class GlobalPlanner:
    62|    def plan_coverage_path(self, vineyard_map, zone) -> Path:
    63|        """生成覆盖所有行的之字形路径"""
    64|        rows = vineyard_map.get_rows(zone)
    65|        path = []
    66|        for row in rows:
    67|            path.append(row.entry_point)
    68|            path.append(row.exit_point)
    69|        return Path(waypoints=path)
    70|
    71|class LocalPlanner:
    72|    def plan_to_waypoint(self, current_pose, waypoint, obstacles) -> Twist:
    73|        """避障前提下的局部路径跟踪"""
    74|```
    75|
    76|### 4.3 行内跟随
    77|
    78|```python
    79|class RowFollower:
    80|    MAX_LATERAL_ERROR = 0.05  # 米
    81|    
    82|    def compute_correction(self, row_line, current_pose) -> Twist:
    83|        """计算保持行内的修正速度"""
    84|        error = distance_to_line(row_line, current_pose)
    85|        if abs(error) > self.MAX_LATERAL_ERROR:
    86|            correction = -error * self.gain
    87|        return Twist(linear=forward_speed, angular=correction)
    88|```
    89|
    90|### 4.4 地头转向
    91|
    92|```python
    93|class HeadlandTurner:
    94|    MAX_TURN_RADIUS_RATIO = 1.5  # 行宽的倍数
    95|    
    96|    def plan_turn(self, from_row, to_row, row_width) -> Path:
    97|        """规划 U 型或 Ω 型转向路径"""
    98|        turn_radius = row_width * self.MAX_TURN_RADIUS_RATIO
    99|        # U-turn for wide rows, Ω-turn for narrow rows
   100|```
   101|
   102|### 4.5 安全约束
   103|
   104|- 定位丢失时必须降速并上报
   105|- 路径偏离 > 阈值时必须重规划
   106|- 始终尊重来自感知子系统的障碍物检测
   107|
   108|## 5. 测试要求
   109|
   110|```python
   111|tests/unit/test_slam.py           # SLAM 算法
   112|tests/unit/test_global_planner.py # 路径规划
   113|tests/unit/test_row_follower.py   # 行内跟随
   114|tests/unit/test_headland_turn.py  # 地头转向
   115|```
   116|
   117|## 6. 配置依赖
   118|
   119|```
   120|config/vineyard_params.yaml  # 行距/行信息
   121|config/robot_params.yaml     # 机器人尺寸
   122|config/safety_params.yaml    # 定位安全参数
   123|```
   124|