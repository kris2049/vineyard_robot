# 运动控制子系统 — 4WD 差速底盘实现计划

> **关联需求**: 用户控制机器人移动（割草刀盘暂忽略）
> **影响子系统**: motion_control, common/types
> **安全等级**: ⚠️ 安全关键

## 目标

实现 4WD 差速驱动机器人的运动控制子系统，包含：运动学解算、安全限幅、速度闭环接口、键盘遥操作控制。用户可通过键盘实时控制机器人移动。

## 设计决策

1. **差速运动学**: 4WD 等同 2WD 差速模型——左侧两轮同速、右侧两轮同速。`linear.x` + `angular.z` → `v_left`, `v_right`
2. **分层架构**: 运动学层 (kinematics) → 安全层 (safety limits) → 执行层 (motor commands)。每层独立可测试
3. **Python 优先**: 当前为仿真验证阶段，用 Python 快速迭代。C++ 在硬件集成阶段替换安全关键路径
4. **输入接口**: 标准 `geometry_msgs/Twist`（cmd_vel），输出为自定义 `WheelVelocity` 消息
5. **键盘遥操作**: 独立 ROS 2 节点，WASD 控制方向，Space 急停

## 任务列表

---

### Task 1: 差速运动学模块

**文件**:
- Create: `src/common/types/wheel_velocity.py` — 自定义消息类型
- Create: `src/motion_control/kinematics.py` — 差速运动学解算
- Create: `tests/unit/test_kinematics.py` — 单元测试

**实现内容**:

1. `WheelVelocity` 数据类：
   - `left: float` — 左轮目标角速度 (rad/s)
   - `right: float` — 右轮目标角速度 (rad/s)

2. `DifferentialDrive` 类：
   - `__init__(wheel_radius, track_width)`: 轮半径(m) + 轮距(m)
   - `forward(linear_x, angular_z) -> WheelVelocity`: 正运动学解算
     - `v_left = (linear_x - angular_z * track_width/2) / wheel_radius`
     - `v_right = (linear_x + angular_z * track_width/2) / wheel_radius`

3. 单元测试覆盖：
   - 纯直线前进 (`linear=1.0, angular=0.0`)
   - 原地旋转 (`linear=0.0, angular=1.0`)
   - 弧线运动 (`linear=0.5, angular=0.5`)
   - 参数边界（零轮径报错、零轮距报错）

**验证**:
```bash
python -m pytest tests/unit/test_kinematics.py -v
```
预期：4 passed

---

### Task 2: 运动控制节点（含安全限幅）

**文件**:
- Create: `src/motion_control/motion_controller.py` — ROS 2 运动控制节点
- Create: `src/motion_control/safety_limits.py` — 安全限幅器
- Create: `tests/unit/test_safety_limits.py` — 安全限幅测试

**实现内容**:

1. `SafetyLimits` 类：
   - `__init__(max_linear, max_angular, max_wheel_rpm)` — 从配置读取
   - `clamp_velocity(cmd_vel: Twist) -> Twist`: 限幅线速度和角速度
   - `is_emergency_stop(estop_active: bool) -> Twist`: 急停返回零速度

2. `MotionController` ROS 2 节点：
   - 订阅 `cmd_vel` (geometry_msgs/Twist)
   - 加载 `DifferentialDrive` + `SafetyLimits`
   - 回调流程: `cmd_vel → 急停检查 → 限幅 → 运动学解算 → wheel_velocity`
   - 发布自定义 `wheel_velocity` topic（供后续电机驱动订阅）
   - 定时器发布诊断状态（100Hz）

3. 测试覆盖：
   - 正常速度转换
   - 超限截断
   - 急停输出零速度

**验证**:
```bash
python -m pytest tests/unit/test_safety_limits.py -v
```
预期：3+ passed

---

### Task 3: 键盘遥操作节点

**文件**:
- Create: `src/motion_control/teleop_keyboard.py` — 键盘控制节点
- Create: `scripts/run_teleop.sh` — 一键启动脚本

**实现内容**:

1. `TeleopKeyboard` ROS 2 节点：
   - 使用 `getch` 读取单键输入（无回车）
   - WASD 控制：
     - `W` — 前进 (linear.x += step)
     - `S` — 后退 (linear.x -= step)
     - `A` — 左转 (angular.z += step)
     - `D` — 右转 (angular.z -= step)
     - `X` — 停止 (linear.x=0, angular.z=0)
     - `Space` — 急停 (发布零速度 + 置 estop 标志)
     - `Q` — 退出
   - 速度步进可配置（默认 linear_step=0.1 m/s, angular_step=0.2 rad/s）
   - 无按键时自动减速归零（timeout 0.5s）
   - 终端实时显示当前速度和状态
   - 发布 `cmd_vel` (geometry_msgs/Twist)

2. 启动脚本 `scripts/run_teleop.sh`

**验证**:
```bash
# 终端 1: 启动运动控制器（仿真模式，无实际硬件）
python src/motion_control/motion_controller.py --sim

# 终端 2: 启动键盘控制
python src/motion_control/teleop_keyboard.py
```
预期：按键 W/A/S/D 可看到终端显示速度变化；Space 急停归零；Q 退出

---

## 依赖

```bash
pip install pynput  # 键盘监听（跨平台）
# ROS 2 (humble/iron) 需已安装
```

## 任务依赖关系

```
Task 1 (运动学) ──→ Task 2 (运动控制节点)
                         │
Task 3 (键盘遥操作) ─────┘ (Task 3 独立，订阅 Task 2 发布 topic)
```

Task 1 和 Task 3 可并行开发。Task 2 依赖 Task 1。
