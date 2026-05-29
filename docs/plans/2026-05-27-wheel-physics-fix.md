# 修复计划 — 小车翻滚问题（物理参数修复）

> **问题**: 轮子打滑 → 车身翻滚
> **根因**: ① 轮子/地面无摩擦系数 ② 圆柱体默认方向沿 Z 轴（应该是 Y 轴） ③ 惯性张量不匹配
> **Worker**: `motion-control`

## Task 1: 修复车轮物理参数

### 修改文件
- `simulation/models/vineyard_mower/model.sdf`

### 修改内容

**A. 每个车轮 link 的 inertial/visual/collision 添加旋转 pose**

轮子作为圆柱体，默认长度沿 Z 轴。需要旋转 90° 使长度沿 Y 轴（轮子平放），才能在 X 方向滚动：
```xml
<link name="left_front_wheel">
    <pose>0 0 0  1.5708 0 0</pose>   <!-- 绕 X 轴旋转 90° -->
```

**B. 修正惯性张量**
- Ixx（绕旋转轴 Y）= 1/2 * m * r² = 0.5 * 2 * 0.0225 = **0.0225**
- Iyy, Izz（横向）= 1/12 * m * (3r² + L²) ≈ **0.0119**
```xml
<inertia>
    <ixx>0.0225</ixx>   <!-- 绕旋转轴 -->
    <ixy>0.0</ixy>
    <ixz>0.0</ixz>
    <iyy>0.0119</iyy>
    <iyz>0.0</iyz>
    <izz>0.0119</izz>
</inertia>
```

**C. 每个 wheel collision 添加摩擦**
```xml
<collision name="lf_wheel_collision">
    ...
    <surface>
        <friction>
            <ode>
                <mu>1.0</mu>
                <mu2>1.0</mu2>
            </ode>
        </friction>
    </surface>
</collision>
```

4 个轮子全部做 A + B + C 修改。

### 约束
- 只改 model.sdf
- 不改 joint 位置和 pose
- 不改 DiffDrive 参数
- 完成后 kanban_complete
