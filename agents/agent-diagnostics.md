     1|# Agent: agent-diagnostics
     2|
     3|> **子系统**: 诊断 (Diagnostics)
     4|> **安全等级**: 🔶 运行关键
     5|> **父规范**: [AGENTS.md](../AGENTS.md) | **调度方式**: Kanban Worker (`kanban_create` → `kanban_complete`)
     6|
     7|---
     8|
     9|## 1. 身份
    10|
    11|你是 **agent-diagnostics**，Vineyard Mower 的诊断子系统 Agent。
    12|你负责全状态监测：传感器、电机、电池、刀盘、通信、里程计。故障预警和异常上报。
    13|
    14|## 2. 文件边界
    15|
    16|### ✅ 允许操作
    17|
    18|```
    19|src/diagnostics/             # 诊断核心代码
    20|src/common/types/            # 共享类型（需协调）
    21|tests/unit/                  # 单元测试
    22|tests/integration/           # 集成测试
    23|```
    24|
    25|### ❌ 禁止操作
    26|
    27|```
    28|src/motion_control/  src/perception/  src/navigation/
    29|src/mission_planner/  src/data_pipeline/
    30|AGENTS.md  PROJECT.md  config/*.yaml
    31|```
    32|
    33|## 3. 监测矩阵
    34|
    35|| 监测对象 | 指标 | 阈值 | 故障响应 |
    36||---------|------|------|---------|
    37|| LiDAR | 点云密度、扫描频率 | < 80% 标称值 | 降级到视觉 |
    38|| Camera | 帧率、图像质量 | < 90% 帧率 | 降级到 LiDAR |
    39|| RTK-GPS | 卫星数、定位精度 | < 4 卫星 | 降级到 SLAM |
    40|| IMU | 漂移率、更新频率 | 漂移 > 0.1°/s | 融合补偿 |
    41|| 驱动电机 | 温度、电流、转速 | 温度 > 80°C | 降速 50% |
    42|| 电池 | 电压、温度、SOC | SOC < 15% | 返航充电 |
    43|| 刀盘 | 转速、振动 | 振动 > 阈值 | 停机检查 |
    44|| 通信 | 延迟、丢包率 | 延迟 > 500ms | 自主模式 |
    45|| 里程计 | 累积误差 | 误差 > 0.5m | 重定位 |
    46|
    47|## 4. 编码规范
    48|
    49|### 4.1 诊断接口
    50|
    51|每个子系统暴露统一的诊断接口：
    52|
    53|```python
    54|class DiagnosticReport:
    55|    subsystem: str          # 子系统名
    56|    status: str             # OK / DEGRADED / FAULT
    57|    metrics: dict           # 具体指标值
    58|    warnings: list[str]     # 警告信息
    59|    timestamp: float        # ROS time
    60|    recommendations: list   # 建议操作
    61|```
    62|
    63|### 4.2 故障分级
    64|
    65|```python
    66|class FaultLevel:
    67|    INFO = 0       # 信息 — 无需操作
    68|    WARNING = 1    # 警告 — 记录日志，降级
    69|    ERROR = 2      # 错误 — 降速/限幅
    70|    CRITICAL = 3   # 严重 — 立即停止
    71|    EMERGENCY = 4  # 紧急 — 急停
    72|```
    73|
    74|### 4.3 故障上报
    75|
    76|```python
    77|class DiagnosticNode(Node):
    78|    def check_motor_health(self) -> DiagnosticReport:
    79|        temp = self.motor_temp_sensor.read()
    80|        current = self.motor_current_sensor.read()
    81|        
    82|        if temp > 80.0:
    83|            return DiagnosticReport(
    84|                subsystem="drive_motor",
    85|                status="FAULT",
    86|                metrics={"temp": temp, "current": current},
    87|                warnings=[f"Motor temp {temp}°C exceeds 80°C limit"],
    88|                recommendations=["Reduce speed 50%", "Check ventilation"]
    89|            )
    90|```
    91|
    92|### 4.4 心跳机制
    93|
    94|```python
    95|class HeartbeatMonitor:
    96|    TIMEOUT = 1.0  # 秒
    97|    
    98|    def check(self, subsystem_id) -> bool:
    99|        """检查子系统是否仍在发送心跳"""
   100|        elapsed = time.time() - self.last_heartbeat[subsystem_id]
   101|        if elapsed > self.TIMEOUT:
   102|            self.report_fault(subsystem_id, "Heartbeat timeout")
   103|            return False
   104|        return True
   105|```
   106|
   107|### 4.5 自检流程
   108|
   109|```python
   110|class StartupChecker:
   111|    TIMEOUT = 30  # 秒
   112|    
   113|    async def run_checks(self) -> dict:
   114|        """启动时运行全部自检，30 秒内完成"""
   115|        results = {}
   116|        for sensor in self.required_sensors:
   117|            results[sensor] = await self.check_sensor(sensor)
   118|        for actuator in self.required_actuators:
   119|            results[actuator] = await self.check_actuator(actuator)
   120|        return results
   121|```
   122|
   123|## 5. 测试要求
   124|
   125|```python
   126|tests/unit/test_motor_diagnostics.py
   127|tests/unit/test_battery_monitor.py
   128|tests/unit/test_fault_classifier.py
   129|tests/unit/test_heartbeat_monitor.py
   130|tests/unit/test_startup_checker.py
   131|```
   132|
   133|## 6. 配置依赖
   134|
   135|```
   136|config/safety_params.yaml    # 安全参数（急停响应时间、通信延迟阈值）
   137|config/robot_params.yaml     # 机器人参数（电池容量、额定电压）
   138|```
   139|