# Vineyard Mower -- Project Context for Claude Code

## For New Team Members
New to the project? Read **`SETUP.md`** first -- it covers Claude Code setup, API key config, and tool installation in 5 minutes.

## Project
Autonomous vineyard mowing robot system (葡萄园自主割草机器人).
- ROS 2 + Gazebo simulation + Python/C++ components
- **Three-role system**: parent_agent (infra + gate) / architect (design + review) / Worker (code)
- Priority: Safety (P0) > Coverage (P1) > Autonomy (P1) > Terrain (P2) > Efficiency (P3)

## Key Docs (read these in order)
1. **AGENTS.md** -- multi-agent workflow, roles, file boundaries, review protocol
2. `PROJECT.md` -- architecture, constraints, safety requirements
3. `COUNCIL.md` -- LLM Council review & oversight system
4. `KNOWLEDGE.md` -- project cognition & knowledge management at scale
5. `docs/plans/` -- implementation plans
6. `docs/decisions/` -- architecture decision records (ADR)

## Role-Specific Docs
- **parent_agent**: AGENTS.md -> PROJECT.md -> COUNCIL.md -> anchor.sh
- **architect** (invoke with `/architect`): AGENTS.md -> PROJECT.md -> COUNCIL.md -> KNOWLEDGE.md
- **Worker**: AGENTS.md 3.2 -> agents/agent-<subsystem>.md -> PROJECT.md

## Session Start
```bash
./scripts/anchor.sh  # Cognitive anchor -- project status, recent changes, role verification
```

## Project Structure
```
vineyard_robot/
├── .claude/settings.json    # Custom agent registration (architect)
├── agents/                  # Agent definition files
│   ├── agent-architect.md
│   ├── agent-motion-control.md
│   └── ...
├── src/
│   ├── motion_control/
│   ├── perception/
│   ├── navigation/
│   ├── mission_planner/
│   ├── diagnostics/
│   ├── data_pipeline/
│   └── common/types/
├── simulation/
│   ├── models/vineyard_mower/
│   └── worlds/
├── config/                  # YAML configs (parent_agent only)
├── tests/                   # pytest test suite
├── docs/
│   ├── plans/
│   └── decisions/
└── scripts/
    ├── anchor.sh
    └── launch_sim.sh
```

## Tech Stack
- ROS 2 Humble (Python/C++)
- Gazebo Garden (Ignition) for simulation
- Python 3.10+ with pytest for testing
- SDF for robot models
- CycloneDDS for ROS 2 middleware on WSL2

## Key Conventions
- **parent_agent NEVER writes src/ code** -- only infra, gate, git
- **architect NEVER writes src/ code** -- only design and review
- **Workers operate within file boundaries** -- see AGENTS.md 3.2
- **Every implementation needs tests** -- `python3 -m pytest tests/ -v`
- **Config changes**: only parent_agent modifies `config/*.yaml`
- **Core docs**: only parent_agent modifies AGENTS.md, PROJECT.md, COUNCIL.md, CLAUDE.md
- **No skip-review**: all code must pass architect review -> parent_agent gate before commit
- **Chinese + English**: documentation in Chinese, code comments in English
- **Safety-critical code**: motion_control and perception subsystems

## WSL2 Quirks
- DDS multicast doesn't work -> use CycloneDDS unicast or Gazebo UserCommands plugin
- SQLite WAL issues on Plan 9 filesystem -> use WAL autocheckpoint
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

## Invoking Agents
- `/architect` -- invoke the system architect agent for design/plan/review tasks
- Workers are created on-demand as sub-agents during implementation phase
