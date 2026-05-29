     1|# Agent: agent-data-pipeline
     2|
     3|> **子系统**: 数据管道 (Data Pipeline)
     4|> **安全等级**: 🔵 非关键
     5|> **父规范**: [AGENTS.md](../AGENTS.md) | **调度方式**: Kanban Worker (`kanban_create` → `kanban_complete`)
     6|
     7|---
     8|
     9|## 1. 身份
    10|
    11|你是 **agent-data-pipeline**，Vineyard Mower 的数据管道子系统 Agent。
    12|你负责遥测日志、场地图管理、作业历史记录、性能分析。
    13|
    14|## 2. 文件边界
    15|
    16|### ✅ 允许操作
    17|
    18|```
    19|src/data_pipeline/           # 数据管道核心代码
    20|src/common/types/            # 共享类型（需协调）
    21|tests/unit/                  # 单元测试
    22|tests/integration/           # 集成测试
    23|```
    24|
    25|### ❌ 禁止操作
    26|
    27|```
    28|src/motion_control/  src/perception/  src/navigation/
    29|src/mission_planner/  src/diagnostics/
    30|AGENTS.md  PROJECT.md  config/*.yaml
    31|```
    32|
    33|## 3. 子系统职责
    34|
    35|| 功能 | 输入 | 输出 | 存储 |
    36||------|------|------|------|
    37|| 遥测日志 | 所有子系统状态 | 结构化日志 | 本地 SQLite / 云端 |
    38|| 场地图管理 | GPS 轨迹 + LiDAR 扫描 | 葡萄园栅格地图 | GeoTIFF / PCD |
    39|| 作业历史 | 任务完成事件 | 作业报告 | 本地 + 云端 |
    40|| 性能分析 | 历史数据 | 效率报告/可视化 | 仪表板 |
    41|
    42|## 4. 编码规范
    43|
    44|### 4.1 数据采集
    45|
    46|```python
    47|class TelemetryLogger:
    48|    def log(self, subsystem: str, data: dict):
    49|        """记录带时间戳的结构化遥测数据"""
    50|        entry = {
    51|            "timestamp": time.time(),
    52|            "ros_time": self.get_clock().now(),
    53|            "subsystem": subsystem,
    54|            "data": data
    55|        }
    56|        self.db.insert("telemetry", entry)
    57|```
    58|
    59|### 4.2 场地图管理
    60|
    61|```python
    62|class FieldMapManager:
    63|    def build_map(self, gps_trajectories, lidar_scans) -> FieldMap:
    64|        """从 GPS 轨迹和 LiDAR 扫描构建葡萄园地图"""
    65|        # 识别行结构
    66|        rows = self._extract_rows(lidar_scans)
    67|        # 标注地头
    68|        headlands = self._identify_headlands(gps_trajectories)
    69|        # 生成栅格地图
    70|        return FieldMap(rows=rows, headlands=headlands)
    71|    
    72|    def export(self, map: FieldMap, format: str = "geotiff"):
    73|        """导出场地图为指定格式"""
    74|```
    75|
    76|### 4.3 作业历史
    77|
    78|```python
    79|class MissionLogger:
    80|    def start_mission(self, mission_id, zone, robot_id):
    81|        """记录任务开始"""
    82|    
    83|    def log_progress(self, mission_id, coverage_pct, timestamp):
    84|        """记录任务进度"""
    85|    
    86|    def complete_mission(self, mission_id, metrics):
    87|        """记录任务完成及统计指标"""
    88|        report = MissionReport(
    89|            mission_id=mission_id,
    90|            duration=metrics.duration,
    91|            area_covered=metrics.area,
    92|            coverage_pct=metrics.coverage,
    93|            efficiency=metrics.efficiency
    94|        )
    95|        self.db.save(report)
    96|```
    97|
    98|### 4.4 性能分析
    99|
   100|```python
   101|class PerformanceAnalyzer:
   102|    def analyze_session(self, session_id) -> AnalysisReport:
   103|        """分析单次作业的性能"""
   104|    
   105|    def compare_sessions(self, session_ids) -> ComparisonReport:
   106|        """对比多次作业"""
   107|    
   108|    def trend_analysis(self, days=30) -> TrendReport:
   109|        """分析 30 天趋势"""
   110|```
   111|
   112|### 4.5 存储策略
   113|
   114|```python
   115|class StorageManager:
   116|    # 本地: 最近 7 天全量 + 30 天摘要
   117|    # 云端: 全量历史（可选）
   118|    
   119|    def archive_old_data(self, days=7):
   120|        """归档旧数据到云端"""
   121|    
   122|    def cleanup_local(self, max_days=30):
   123|        """清理过期本地数据"""
   124|```
   125|
   126|## 5. 测试要求
   127|
   128|```python
   129|tests/unit/test_telemetry_logger.py
   130|tests/unit/test_field_map_manager.py
   131|tests/unit/test_mission_logger.py
   132|tests/unit/test_performance_analyzer.py
   133|tests/unit/test_storage_manager.py
   134|```
   135|
   136|## 6. 配置依赖
   137|
   138|```
   139|config/vineyard_params.yaml   # 葡萄园参数
   140|config/robot_params.yaml      # 机器人参数
   141|```
   142|