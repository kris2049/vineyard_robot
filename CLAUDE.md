# Vineyard Mower — Project Context for Claude Code

## Project
Autonomous vineyard mowing robot system (葡萄园自主割草机器人).
- ROS 2 + Gazebo simulation + Python/C++ components
- Multi-agent architecture: parent_agent orchestrator + 6 specialized worker profiles
- Priority: Safety (P0) > Coverage (P1) > Autonomy (P1) > Terrain (P2) > Efficiency (P3)

## Key Docs (read these first)
- `PROJECT.md` — architecture, constraints, safety requirements
- `AGENTS.md` — multi-agent Kanban workflow, file boundaries, review protocol
- `COUNCIL.md` — LLM Council review & oversight system (multi-agent adversarial review)
- `KNOWLEDGE.md` — project cognition & knowledge management at scale
- `docs/plans/` — implementation plans
- `docs/decisions/` — architecture decision records (ADR)

## Session Start
```bash
./scripts/anchor.sh  # Cognitive anchor — project status, recent changes, CodeGraph sync
```

## Project Structure
```
vineyard_robot/
├── src/
│   ├── motion_control/   # Differential drive, PID, kinematics
│   ├── perception/       # LiDAR, camera, sensor fusion
│   ├── navigation/       # Path planning, SLAM, localization
│   ├── mission_planner/  # Coverage planning, task scheduling
│   ├── diagnostics/      # Health monitoring, fault detection
│   ├── data_pipeline/    # Data collection, logging, telemetry
│   └── common/types/     # Shared message types
├── simulation/
│   ├── models/vineyard_mower/  # SDF/URDF robot models
│   └── worlds/                 # Gazebo world files
├── config/               # YAML configs (parent_agent only)
├── tests/                # pytest test suite
└── docs/plans/           # Implementation plans
```

## Tech Stack
- ROS 2 Humble (Python/C++)
- Gazebo Garden (Ignition) for simulation
- Python 3.10+ with pytest for testing
- SDF for robot models
- CycloneDDS for ROS 2 middleware on WSL2

## Key Conventions
- **parent_agent NEVER writes src/ code** — only review, architect, dispatch
- **Workers operate within file boundaries** — see AGENTS.md §8
- **Every implementation needs tests** — `python3 -m pytest tests/ -v`
- **Config changes**: only parent_agent modifies `config/*.yaml`
- **Chinese + English**: documentation in Chinese, code comments in English
- **Safety-critical code**: motion_control and perception subsystems

## WSL2 Quirks
- DDS multicast doesn't work → use CycloneDDS unicast or Gazebo UserCommands plugin
- SQLite WAL issues on Plan 9 filesystem → use WAL autocheckpoint
- Keyboard input for Gazebo: use `gz topic` commands or termios Python script

## Key Commands
```bash
# Run tests
python3 -m pytest tests/ -v

# Lint Python
ruff check src/

# Build ROS 2 workspace
colcon build --symlink-install

# Start Gazebo simulation
gz sim simulation/worlds/vineyard.sdf

# SDF validation
python3 -c "import xml.etree.ElementTree as ET; ET.parse('model.sdf')"
```

## Active Development
When starting work, check `docs/plans/` for the latest plan and `PROJECT.md` for current architecture state.
