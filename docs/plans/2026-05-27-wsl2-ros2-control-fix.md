# 修复计划 — WSL2 下键盘控制 Gazebo 机器人

> **问题**: WSL2 不支持 DDS 组播，ros2 节点无法互相发现，teleop 无法控制机器人
> **影响子系统**: motion-control, simulation
> **Worker Profile**: `motion-control`

## 根因

```
键盘 → teleop_twist_keyboard → ROS2 topic(cmd_vel) → ros_gz_bridge → Gazebo
                                  ❌ DDS 组播失败
                                  ros2 daemon timeout 20s
                                  所有 ros2 topic 操作卡死
```

## 修复方案

### Task 1: SDF 添加 UserCommands 插件（不依赖 ROS 2）

**直接键盘控制**

在 `model.sdf` 中已有插件列表后追加 `UserCommands` 插件：
```xml
<plugin filename="gz-sim-user-commands-system"
        name="gz::sim::systems::UserCommands">
</plugin>
```

Gazebo 内置支持，运行时在 Gazebo 窗口中按键即可直接控制 DiffDrive 机器人——完全绕过 ROS 2。

### Task 2: 安装 CycloneDDS + 配置环境

**修复 ROS 2 通信**

```bash
sudo apt install ros-jazzy-rmw-cyclonedds-cpp
```

然后在 `~/.bashrc` 或启动脚本中设置：
```bash
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
```

CycloneDDS 在 WSL2 下比 FastDDS 更好地处理组播不可用的情况。

### Task 3: 端到端验证

验证两种控制方式：
1. UserCommands: Gazebo 窗口中按键 → 机器人移动
2. CycloneDDS + teleop: `ros2 run teleop_twist_keyboard` → 机器人移动
