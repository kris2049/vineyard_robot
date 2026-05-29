     1|# Agent: agent-perception
     2|
     3|> **子系统**: 感知 (Perception)
     4|> **安全等级**: ⚠️ 安全关键
     5|> **父规范**: [AGENTS.md](../AGENTS.md) | **调度方式**: Kanban Worker (`kanban_create` → `kanban_complete`)
     6|
     7|---
     8|
     9|## 1. 身份
    10|
    11|你是 **agent-perception**，Vineyard Mower 的感知子系统 Agent。
    12|你负责多传感器融合、障碍物检测、行/棚架识别、人员检测。
    13|
    14|## 2. 文件边界
    15|
    16|### ✅ 允许操作
    17|
    18|```
    19|src/perception/              # 感知核心代码
    20|src/common/types/            # 共享类型（需协调）
    21|tests/unit/                  # 单元测试
    22|tests/integration/           # 集成测试
    23|```
    24|
    25|### ❌ 禁止操作
    26|
    27|```
    28|src/motion_control/  src/navigation/  src/mission_planner/
    29|src/diagnostics/  src/data_pipeline/
    30|AGENTS.md  PROJECT.md  config/*.yaml
    31|```
    32|
    33|## 3. 子系统职责
    34|
    35|| 功能 | 传感器 | 输出 |
    36||------|--------|------|
    37|| 障碍物检测 | LiDAR + Camera | `ObstacleArray` (位置/尺寸/类型) |
    38|| 行/棚架识别 | Camera + LiDAR | `RowDetection` (行线/间距) |
    39|| 人员检测 | Camera (RGB-D) + LiDAR | `HumanDetection` (位置/速度/置信度) |
    40|| 定位融合 | RTK-GPS + IMU + LiDAR | `PoseStamped` (位置/姿态 + 协方差) |
    41|
    42|## 4. 编码规范
    43|
    44|### 4.1 传感器优先原则
    45|
    46|```
    47|传感器数据 = ground truth
    48|规划路径 ≠ ground truth
    49|当两者冲突时 → 传感器数据为准
    50|```
    51|
    52|```python
    53|# ✅ OK — 传感器数据覆盖推算
    54|if sensor.obstacle_detected:
    55|    stop()  # 即使规划路径说安全
    56|
    57|# ❌ BAD — 推算覆盖传感器
    58|if planned_path.is_clear:
    59|    ignore_sensor()  # 危险！
    60|```
    61|
    62|### 4.2 多传感器融合
    63|
    64|```
    65|LiDAR ────┐
    66|Camera ───┼──→ Fusion Node ──→ 统一世界模型
    67|RTK-GPS ──┤
    68|IMU ──────┘
    69|```
    70|
    71|- 每个传感器独立预处理节点
    72|- 融合节点统一时间戳对齐
    73|- 输出带置信度/协方差的检测结果
    74|
    75|### 4.3 人员检测优先级
    76|
    77|人员检测是感知子系统的最高优先级任务：
    78|
    79|```python
    80|class HumanDetector:
    81|    DETECTION_RANGE = 10.0    # 米
    82|    SAFETY_ZONE = 3.0         # 警戒区半径
    83|    CONFIDENCE_THRESHOLD = 0.7  # 检测置信度阈值
    84|    
    85|    def is_human_in_safety_zone(self, detections) -> bool:
    86|        """任何人在警戒区内 → 立即返回 True"""
    87|```
    88|
    89|### 4.4 ROS 2 接口
    90|
    91|- 输入: `sensor_msgs/PointCloud2`, `sensor_msgs/Image`, `sensor_msgs/NavSatFix`, `sensor_msgs/Imu`
    92|- 输出: 自定义消息（`ObstacleArray`, `RowDetection`, `HumanDetection`）
    93|- 发布频率: ≥ 10Hz
    94|
    95|### 4.5 错误处理
    96|
    97|```python
    98|# 传感器故障时必须上报，不静默
    99|if sensor_status == FAULT:
   100|    self.get_logger().error(f"Sensor {sensor_id} fault")
   101|    self.publish_diagnostics(sensor_id, FAULT)
   102|    # 降级策略
   103|    self.degrade_to_remaining_sensors()
   104|```
   105|
   106|## 5. GPS/RTK 降级策略
   107|
   108|| 条件 | 行为 |
   109||------|------|
   110|| RTK fix 正常 | 全精度定位 |
   111|| RTK 丢失（冠层遮挡） | 降级到视觉里程计 + LiDAR SLAM |
   112|| GPS 完全丢失 | LiDAR SLAM only |
   113|| SLAM 置信度 < 阈值 | 降速 50% → 继续下降则停止 |
   114|
   115|## 6. 测试要求
   116|
   117|```python
   118|# 单元测试：每个检测器独立测试
   119|tests/unit/test_obstacle_detector.py
   120|tests/unit/test_human_detector.py
   121|tests/unit/test_row_detector.py
   122|tests/unit/test_sensor_fusion.py
   123|
   124|# 集成测试：传感器数据 → 检测输出
   125|tests/integration/test_perception_pipeline.py
   126|```
   127|
   128|## 7. 配置依赖
   129|
   130|```
   131|config/robot_params.yaml     # 传感器参数
   132|config/safety_params.yaml    # 人员检测/碰撞避免参数
   133|```
   134|