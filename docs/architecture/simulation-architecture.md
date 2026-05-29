# 仿真架构设计

> **版本**: 2.0.0
> **仿真引擎**: Gazebo Harmonic (gz-sim8, vendor via ROS 2 Jazzy)
> **中间件**: ROS 2 Jazzy LTS
> **桥接**: ros_gz_bridge

---

## 0. 前置分析：为什么 ROS 2 不"过重"

已有代码全部是 ROS 2 架构：

```
src/motion_control/motion_controller.py  ← rclpy.Node
src/motion_control/teleop_keyboard.py    ← rclpy.Node
scripts/verify_motion.py                 ← rclpy + MotionController
```

换轻量框架意味着抛弃所有已有代码。而且 ROS 2 Jazzy 提供了我们需要的全部基础设施：

| ROS 2 提供 | 自己写成本 |
|-----------|-----------|
| `teleop_twist_keyboard` | ~500 行终端控制 |
| `diff_drive_controller` | ~200 行运动学+控制 |
| `ros_gz_bridge` | ~1000 行协议桥接 |
| `nav2` (后续) | ~5000 行导航栈 |
| DDS 通信 | ~3000 行中间件 |

**结论：ROS 2 Jazzy + Gazebo Harmonic 是当前环境下的最优方案，不是过重，而是恰好。**

---

## 1. 架构总览

```
┌──────────────────────────────────────────────────────────────────┐
│                        用户交互层                                 │
│                                                                  │
│  ┌─────────────────────┐    ┌──────────────────────────────┐    │
│  │ teleop_twist_keyboard│    │    verify_motion.py          │    │
│  │ (ROS 2 内置, WASD)   │    │    (已有, 自动化测试)        │    │
│  └─────────┬───────────┘    └──────────────┬───────────────┘    │
│            │ cmd_vel (Twist)               │ cmd_vel             │
│            └───────────────┬───────────────┘                     │
└────────────────────────────┼────────────────────────────────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
              ▼                             ▼
┌─────────────────────────┐   ┌─────────────────────────────────┐
│  单元测试路径 (已有)      │   │   仿真路径 (新增)                │
│                         │   │                                 │
│  motion_controller.py   │   │  ros_gz_bridge                  │
│  → SafetyLimits         │   │  (cmd_vel → gz.msgs.Twist)      │
│  → DifferentialDrive    │   │          │                      │
│  → Float64MultiArray    │   │          ▼                      │
│                         │   │  Gazebo Harmonic                │
│  ✅ 26 tests passing    │   │  ┌───────────────────────────┐  │
│                         │   │  │ vineyard_mower.sdf        │  │
│                         │   │  │   DiffDrive plugin        │  │
│                         │   │  │   JointStatePublisher      │  │
│                         │   │  │   IMU sensor               │  │
│                         │   │  │   Lidar sensor             │  │
│                         │   │  └───────────────────────────┘  │
│                         │   │          │                      │
│                         │   │  ┌───────────────────────────┐  │
│                         │   │  │ vineyard.world.sdf        │  │
│                         │   │  │   地面 + 行标 + 立柱      │  │
│                         │   │  └───────────────────────────┘  │
└─────────────────────────┘   └─────────────────────────────────┘
```

**双重验证策略：**
- **单元测试路径**（已有）：验证 SafetyLimits + DifferentialDrive 逻辑正确性
- **仿真路径**（新增）：验证物理行为 + 传感器 + 场景交互

---

## 2. 组件清单

### 2.1 已有（不需写代码）

| 组件 | 位置 | 说明 |
|------|------|------|
| `MotionController` | `src/motion_control/motion_controller.py` | ROS 2 运动控制节点 |
| `SafetyLimits` | `src/motion_control/safety_limits.py` | 安全限幅器 |
| `DifferentialDrive` | `src/motion_control/kinematics.py` | 差速运动学 |
| `WheelVelocity` | `src/common/types/wheel_velocity.py` | 轮速数据类型 |
| 单元测试 | `tests/unit/test_*.py` | 20+ unit tests |
| 集成测试 | `tests/integration/test_motion_pipeline.py` | Pipeline 测试 |
| `verify_motion.py` | `scripts/verify_motion.py` | 独立验证脚本 |
| `teleop_twist_keyboard` | ROS 2 内置 (`ros2 run`) | 键盘遥操作 |
| `ros_gz_bridge` | ROS 2 内置 | ROS ↔ Gazebo 桥接 |
| `gz sim` | Gazebo Harmonic CLI | 仿真引擎 |

### 2.2 需要创建

| 组件 | 文件路径 | 说明 |
|------|---------|------|
| **机器人模型** | `simulation/models/vineyard_mower/model.sdf` | 4WD 差速底盘 SDF |
| **模型配置** | `simulation/models/vineyard_mower/model.config` | Gazebo 模型元数据 |
| **葡萄园世界** | `simulation/worlds/vineyard.world.sdf` | 行间结构 + 地面 |
| **桥接配置** | `config/gz_bridge.yaml` | ROS↔GZ topic 映射 |
| **启动脚本** | `scripts/launch_sim.sh` | 一键启动仿真 |
| **仿真测试** | `tests/integration/test_gazebo_bridge.py` | 桥接验证 |

---

## 3. SDF 机器人模型设计

```
vineyard_mower (4WD 差速底盘)

      1.2m (chassis length)
  ┌─────────────────────┐
  │                     │
  │    ┌───────────┐    │  ← IMU sensor frame
  │    │   Body    │    │
  │    │  250kg    │    │
  │    └───────────┘    │
  │                     │  0.8m (chassis width)
  │  ○             ○   │  ← 左前轮 / 右前轮
  │                     │
  │  ○             ○   │  ← 左后轮 / 右后轮
  └─────────────────────┘
    ← 0.9m wheel_base →
    ← 0.65m track_width →

底盘参数 (来自 config/robot_params.yaml):
  - 长×宽×高: 1.2 × 0.8 × 0.4 m
  - 轮半径: 0.15 m, 轮距: 0.65 m, 轴距: 0.9 m
  - 质量: 250 kg

Gazebo 插件:
  - DiffDrive: left_joint=[left_front, left_rear], right_joint=[right_front, right_rear]
  - JointStatePublisher: 发布所有 4 个轮子关节状态
  - IMU: 固定在底盘中心
  - OdometryPublisher: 基于差速模型
```

---

## 4. 葡萄园世界设计

```
vineyard.world (俯视图)

  ╔═══════════════════════════════════════════╗
  ║                 headland (地头)            ║
  ║                                           ║
  ║  │  Row 1  │  Row 2  │  Row 3  │  Row 4 ║
  ║  │         │         │         │         ║
  ║  │ ○  ○  ○ │ ○  ○  ○ │ ○  ○  ○ │ ○  ○  ○║  ← 立柱 (圆柱体)
  ║  │   8m    │   8m    │   8m    │   8m   ║  ← 行内区域
  ║  │         │         │         │         ║
  ║  │         │         │         │         ║
  ║                                           ║
  ║                 headland                   ║
  ╚═══════════════════════════════════════════╝

  行距: 2.8m (可配置)
  行内长度: 8m
  行数: 4 (轻量测试场景)
  立柱: 圆柱体 φ0.08m × H1.8m, 间距 2m
  地面: 平面 + 摩擦系数模拟草地
```

---

## 5. 消息流

```
键盘 ──cmd_vel──→ ros_gz_bridge ──gz.msgs.Twist──→ Gazebo DiffDrive
                                                          │
                                                    4 轮关节转动
                                                          │
                                                  物理引擎 (DART)
                                                          │
Gazebo ←── 位姿/IMU/里程计 ── ros_gz_bridge ──→ ROS 2 topics
                                                      │
                                              终端显示 / 数据记录
```

**注：仿真路径不使用我们自己的 MotionController**。Gazebo 的 DiffDrive plugin 负责运动学解算。我们的 MotionController 通过单元测试独立验证，未来硬件阶段替换 Gazebo 的 DiffDrive。

---

## 6. 为什么不写自己的仿真引擎

| 方案 | 工作量 | 物理真实度 | 传感器模拟 | 可扩展性 |
|------|--------|-----------|-----------|---------|
| Gazebo Harmonic | ~2h 写 SDF | 高 (DART) | 内置 LiDAR/IMU/Camera | 直接对接后续 nav2/SLAM |
| PyBullet | ~8h 写 Python | 中 | 需手写 | 弱 |
| 纯 Python 运动学 | ~4h | 无物理 | 无 | 需全部重建 |

Gazebo 写几个 SDF 文件就能得到：物理仿真 + 传感器 + 3D 可视化 + ROS 2 桥接。自研仿真引擎在 Phase 1 是过度工程。

---

*仿真阶段的核心产出：1 个机器人模型 + 1 个葡萄园世界 + 1 个启动脚本。代码量 < 500 行 SDF。*
