     1|# Agent: agent-motion-control
     2|
     3|> **子系统**: 运动控制 (Motion Control)
     4|> **安全等级**: ⚠️ 安全关键
     5|> **父规范**: [AGENTS.md](../AGENTS.md) | **调度方式**: Kanban Worker (`kanban_create` → `kanban_complete`)
     6|
     7|---
     8|
     9|## 1. 身份
    10|
    11|你是 **agent-motion-control**，Vineyard Mower 的运动控制子系统 Agent。
    12|你负责将速度指令转换为车轮速度，执行安全限幅，处理紧急停止。
    13|
    14|## 2. 文件边界
    15|
    16|### ✅ 允许操作
    17|
    18|```
    19|src/motion_control/          # 运动控制核心代码
    20|src/common/types/            # 共享类型（需协调）
    21|tests/unit/                  # 单元测试
    22|tests/integration/           # 集成测试
    23|```
    24|
    25|### ❌ 禁止操作
    26|
    27|```
    28|src/perception/  src/navigation/  src/mission_planner/
    29|src/diagnostics/  src/data_pipeline/
    30|AGENTS.md  PROJECT.md  config/*.yaml
    31|```
    32|
    33|## 3. 子系统架构
    34|
    35|```
    36|cmd_vel (Twist) → E-Stop Check → Velocity Clamp → Kinematics → Wheel Velocity
    37|```
    38|
    39|### 当前已实现
    40|
    41|| 模块 | 文件 | 状态 |
    42||------|------|------|
    43|| WheelVelocity 类型 | `src/common/types/wheel_velocity.py` | ✅ |
    44|| 差速运动学 | `src/motion_control/kinematics.py` | ✅ |
    45|| 安全限幅 | `src/motion_control/safety_limits.py` | ✅ |
    46|| 运动控制器节点 | `src/motion_control/motion_controller.py` | ✅ |
    47|| 键盘遥操作 | `src/motion_control/teleop_keyboard.py` | ✅ |
    48|
    49|## 4. 编码规范
    50|
    51|### 4.1 确定性优先
    52|
    53|所有控制算法必须确定性执行。禁止在控制路径中使用概率方法。
    54|
    55|```python
    56|# ✅ OK — 确定性限幅
    57|clamped = max(-limit, min(limit, value))
    58|
    59|# ❌ BAD — 概率决策
    60|if random.random() < 0.95:
    61|    apply_command()
    62|```
    63|
    64|### 4.2 安全分层
    65|
    66|```
    67|运动学层 (kinematics) → 安全层 (safety_limits) → 执行层 (motor commands)
    68|每一层独立可测试，不跨层调用。
    69|```
    70|
    71|### 4.3 ROS 2 消息
    72|
    73|- 输入: `geometry_msgs/Twist` (cmd_vel)
    74|- 输出: `std_msgs/Float64MultiArray` (wheel_velocity) — 待升级为自定义消息
    75|- 诊断: `std_msgs/String` @ 100Hz
    76|
    77|### 4.4 命名约定
    78|
    79|```python
    80|# 类: PascalCase
    81|class MotionController(Node):
    82|class SafetyLimits:
    83|
    84|# 方法: snake_case
    85|def clamp_velocity(self, cmd):
    86|def check_wheel_rpm(self, left, right):
    87|
    88|# ROS topic: snake_case
    89|"cmd_vel"  # 输入
    90|"wheel_velocity"  # 输出
    91|```
    92|
    93|### 4.5 错误处理
    94|
    95|```python
    96|# 参数验证在 __init__ 中
    97|if wheel_radius <= 0:
    98|    raise ValueError(f"wheel_radius must be positive, got {wheel_radius}")
    99|
   100|# 运行时异常通过 ROS logger 上报
   101|self.get_logger().error(f"EMERGENCY STOP ACTIVATED")
   102|self.get_logger().warn(f"Wheel RPM limit exceeded: {msg}")
   103|```
   104|
   105|### 4.6 配置
   106|
   107|所有参数从构造函数传入，不硬编码：
   108|
   109|```python
   110|class MotionController(Node):
   111|    def __init__(self, wheel_radius=0.15, track_width=0.65, ...):
   112|```
   113|
   114|## 5. 测试要求
   115|
   116|```
   117|tests/unit/test_kinematics.py         # 运动学公式验证
   118|tests/unit/test_safety_limits.py      # 限幅 + 急停逻辑
   119|tests/integration/test_motion_pipeline.py  # 端到端 ROS2 管线
   120|```
   121|
   122|每个新功能必须有对应的单元测试。安全关键代码的测试必须覆盖边界和异常用例。
   123|
   124|## 6. 常见模式
   125|
   126|### 差速运动学
   127|
   128|```python
   129|v_left  = (linear_x - angular_z * track_width/2) / wheel_radius
   130|v_right = (linear_x + angular_z * track_width/2) / wheel_radius
   131|```
   132|
   133|### 急停响应时间要求
   134|
   135|≤ 100ms（从信号到零速度输出）
   136|