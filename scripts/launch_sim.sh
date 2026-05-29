#!/bin/bash
# ============================================================================
# Vineyard Mower — One-Click Simulation Launch
# Starts Gazebo Harmonic (headless), spawns the robot, and bridges ROS 2 topics.
# ============================================================================
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODEL_SDF="${PROJECT_ROOT}/simulation/models/vineyard_mower/model.sdf"
BRIDGE_CONFIG="${PROJECT_ROOT}/config/gz_bridge.yaml"

# --- source ROS 2 environment ---
if [ -f /opt/ros/jazzy/setup.bash ]; then
    source /opt/ros/jazzy/setup.bash
else
    echo "ERROR: ROS 2 Jazzy not found at /opt/ros/jazzy/"
    exit 1
fi

# --- configure RMW for WSL2 ---
# Option 1: CycloneDDS (preferred — handles missing multicast better)
# Install with: sudo apt install -y ros-jazzy-rmw-cyclonedds-cpp
if [ -f /opt/ros/jazzy/setup.bash ] && [ -f /opt/ros/jazzy/lib/librmw_cyclonedds_cpp.so ]; then
    export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
    echo "RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION}"
# Option 2: FastDDS unicast fallback (no multicast needed)
elif [ -f "${PROJECT_ROOT}/config/dds/fastdds_unicast.xml" ]; then
    export FASTRTPS_DEFAULT_PROFILES_FILE="${PROJECT_ROOT}/config/dds/fastdds_unicast.xml"
    echo "RMW=FastDDS (unicast via ${FASTRTPS_DEFAULT_PROFILES_FILE})"
fi

# --- set Gazebo model path ---
export GZ_SIM_RESOURCE_PATH="${PROJECT_ROOT}/simulation/models:${GZ_SIM_RESOURCE_PATH}"

# --- validate prerequisites ---
if [ ! -f "$MODEL_SDF" ]; then
    echo "ERROR: model.sdf not found at ${MODEL_SDF}"
    exit 1
fi
if [ ! -f "$BRIDGE_CONFIG" ]; then
    echo "ERROR: gz_bridge.yaml not found at ${BRIDGE_CONFIG}"
    exit 1
fi

# --- cleanup on exit ---
cleanup() {
    echo ""
    echo "=== shutting down ==="
    [ -n "$BRIDGE_PID" ] && kill "$BRIDGE_PID" 2>/dev/null
    [ -n "$GZ_PID" ] && kill "$GZ_PID" 2>/dev/null
    wait 2>/dev/null
    echo "=== simulation stopped ==="
}
trap cleanup EXIT INT TERM

# --- start Gazebo (headless, empty world) ---
echo "=== starting Gazebo Harmonic ==="
gz sim -r -v 4 empty.sdf --render-engine ogre &
GZ_PID=$!
sleep 3

# --- spawn vineyard_mower model ---
echo "=== spawning vineyard_mower ==="
gz service -s /world/empty/create \
    --reqtype gz.msgs.EntityFactory \
    --reptype gz.msgs.Boolean \
    -r "sdf_filename: \"${MODEL_SDF}\", name: \"vineyard_mower\""
sleep 2

# --- start ROS 2 ↔ Gazebo bridge ---
echo "=== starting ros_gz_bridge ==="
ros2 run ros_gz_bridge parameter_bridge \
    --ros-args -p config_file:="${BRIDGE_CONFIG}" &
BRIDGE_PID=$!
sleep 2

echo ""
echo "╔══════════════════════════════════════╗"
echo "║      SIMULATION READY                ║"
echo "╠══════════════════════════════════════╣"
echo "║ Gazebo PID : ${GZ_PID}"
echo "║ Bridge PID : ${BRIDGE_PID}"
echo "╠══════════════════════════════════════╣"
echo "║ Control (new terminal):              ║"
echo "║  python3 scripts/keyboard_control.py ║"
echo "║                                      ║"
echo "║  W/S: fwd/back  A/D: turn  Q: quit  ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Press Ctrl+C to stop."

# --- wait for termination ---
wait
