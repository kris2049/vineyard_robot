# 仿真实现计划 — 控制小车在 Gazebo 中移动

> **关联需求**: 在 Gazebo Harmonic 中实现 4WD 差速底盘的运动控制仿真
> **影响子系统**: motion_control, simulation
> **Worker Profiles**: `motion-control`, `data-pipeline`
> **安全等级**: ⚠️ 安全关键（需验证急停链路）

## 目标

在 Gazebo Harmonic 中创建一个 4WD 差速底盘机器人模型，通过 ROS 2 `teleop_twist_keyboard` 实时遥控，使用 `ros_gz_bridge` 桥接通信。先在平坦地面上验证运动，后续再加葡萄园场景。

## 设计决策

1. **Gazebo DiffDrive plugin** 处理运动学（不用我们自己的 kinematics.py — 那是为真实硬件准备的）
2. **4 个独立轮关节**，DiffDrive 自动驱动左2右2
3. **先平地面**，葡萄园立柱和行结构下一轮加
4. **Headless 模式运行**（WSL2 无 GPU），终端验证

## 任务列表

---

### Task 1: 创建 4WD 差速底盘 SDF 模型

**Worker**: `motion-control`
**依赖**: 无
**文件**:
- Create: `simulation/models/vineyard_mower/model.sdf`
- Create: `simulation/models/vineyard_mower/model.config`

**内容**:
1. 4 个驱动轮 (left_front, left_rear, right_front, right_rear)，每个带 revolute joint
2. 底盘 body（box collision + visual），参数对齐 `config/robot_params.yaml`:
   - 长×宽×高: 1.2 × 0.8 × 0.4m
   - 轮半径 0.15m，轮距 0.65m，轴距 0.9m
   - 质量 250kg
3. 集成 Gazebo 插件:
   - `DiffDrive`: left_joint=[left_front_joint, left_rear_joint], right_joint=[right_front_joint, right_rear_joint]
   - `JointStatePublisher`: 发布所有关节状态
   - `IMU`: 固定在 base_link
4. `model.config` 元数据（名称、作者、描述）

**验证**:
```bash
# 在空世界中加载模型
source /opt/ros/jazzy/setup.bash
export GZ_SIM_RESOURCE_PATH=$GZ_SIM_RESOURCE_PATH:/home/kris/vineyard_robot/simulation/models
gz sim -r -v 4 empty.sdf --render-engine ogre &
# 插入模型
gz service -s /world/empty/create --reqtype gz.msgs.EntityFactory --reptype gz.msgs.Boolean \
  -r 'sdf_filename: "model.sdf", name: "vineyard_mower"'
# 查看 topic
gz topic -l | grep -E "cmd_vel|joint|odom"
```
预期: 看到 `/model/vineyard_mower/cmd_vel` 等 topic

---

### Task 2: 配置 ros_gz_bridge + 编写启动脚本

**Worker**: `motion-control`
**依赖**: Task 1

**文件**:
- Create: `config/gz_bridge.yaml`
- Create: `scripts/launch_sim.sh`

**内容**:
1. `gz_bridge.yaml` 桥接配置:
   - `cmd_vel` (Twist) ←→ `model/vineyard_mower/cmd_vel` (gz.msgs.Twist)
   - `odom` (Odometry) ←→ `model/vineyard_mower/odometry` (gz.msgs.Odometry)
   - `joint_states` (JointState) ←→ `/world/empty/model/vineyard_mower/joint_state` (gz.msgs.Model)
2. `launch_sim.sh`:
   - source ROS 2 环境
   - 设置 GZ_SIM_RESOURCE_PATH
   - 启动 Gazebo 加载 vineyard_mower 模型 (headless 模式)
   - 启动 ros_gz_bridge
   - 提示用户在新终端运行 `ros2 run teleop_twist_keyboard teleop_twist_keyboard`

**验证**:
```bash
# 终端 1: 启动仿真
bash scripts/launch_sim.sh

# 终端 2: 检查 bridge
source /opt/ros/jazzy/setup.bash
ros2 topic list | grep -E "cmd_vel|odom|joint"
```
预期: 看到 `/cmd_vel`, `/odom`, `/joint_states` 在 ROS 2 topic 列表中

---

### Task 3: 端到端验证 — 键盘控制小车移动

**Worker**: `motion-control`
**依赖**: Task 2

**内容**:
1. 运行完整流程:
   - 终端 1: `bash scripts/launch_sim.sh`
   - 终端 2: `source /opt/ros/jazzy/setup.bash && ros2 run teleop_twist_keyboard teleop_twist_keyboard`
2. 验证按键 → cmd_vel → Gazebo 中的机器人移动
3. 记录验证结果（终端截图/日志）

**验证**:
```bash
# 终端 3: 监视 odometry 确认机器人移动
source /opt/ros/jazzy/setup.bash
ros2 topic echo /odom --once
```
预期: 按 W 键后 odom 中 position.x > 0

---

## 任务依赖图

```
Task 1 (SDF 模型) ──→ Task 2 (桥接+启动) ──→ Task 3 (端到端验证)
  motion-control        motion-control          motion-control
```

所有 Task 串行，依赖明确。每个 Task 完成后 `kanban_block` 等待父 Agent 审查。
