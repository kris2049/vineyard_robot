#!/bin/bash
# anchor.sh -- Cognitive Anchor for Vineyard Mower Agent Sessions
#
# Run at START of every session. All agents must run this first.
# Syncs awareness of project state, git status, and workflow rules.
#
# Usage: ./scripts/anchor.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "============================================"
echo "  Vineyard Mower -- Cognitive Anchor"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
echo ""

# 1. Git status
echo "Git Status:"
BRANCH=$(git branch --show-current)
COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo "0")
echo "  Branch: $BRANCH | Commits: $COMMITS"
echo "  Remote: $(git remote get-url origin 2>/dev/null || echo 'none')"
echo ""
echo "  Latest commits:"
git log --oneline -5 2>/dev/null | sed 's/^/    /'
if [ -n "$(git status --porcelain)" ]; then
  echo ""
  echo "  Uncommitted changes:"
  git status --short | sed 's/^/    /'
else
  echo ""
  echo "  Working tree clean"
fi

echo ""

# 2. Plans and decisions
echo "Current Plans:"
if ls docs/plans/*.md 2>/dev/null | head -10 | grep -q .; then
  ls docs/plans/*.md 2>/dev/null | sed 's/^/  - /'
else
  echo "  (none)"
fi

echo ""

# 3. Three-role workflow reminder (AGENTS.md)
echo "AGENTS.md Workflow Reminder:"
echo "  parent_agent: infrastructure + gate + git (NO src/ code)"
echo "  architect:    design + review (NO src/ code, NO git)"
echo "  Worker:       code implementation only (file boundaries)"
echo ""
echo "  Hard rules:"
echo "  1. parent_agent NEVER writes src/"
echo "  2. architect NEVER writes src/ or uses git"
echo "  3. Workers NEVER modify core docs"
echo "  4. ALL code must pass review before commit"
echo "  5. No skip-review allowed"
echo ""

# 4. Subsystem state
echo "Subsystem Source Files:"
for dir in src/motion_control src/perception src/navigation src/mission_planner src/diagnostics src/data_pipeline; do
    count=$(find "$dir" -name "*.py" ! -name "__init__.py" 2>/dev/null | wc -l)
    printf "  %-25s %2d files\n" "$dir:" "$count"
done
count=$(find src/common -name '*.py' ! -name "__init__.py" 2>/dev/null | wc -l)
echo "  src/common/types:         $count files"

echo ""

# 5. Test count
test_count=$(find tests -name "test_*.py" 2>/dev/null | wc -l)
echo "Test files: $test_count"
echo ""

# 6. Environment
echo "Environment:"
echo "  Python: $(python3 --version 2>/dev/null || echo 'not found')"
echo "  Pytest: $(python3 -m pytest --version 2>/dev/null | head -1 || echo 'not found')"
if command -v ruff &>/dev/null; then
  echo "  Ruff: $(ruff --version 2>/dev/null)"
else
  echo "  Ruff: not found"
fi

echo ""
echo "============================================"
echo "  Anchor complete -- proceed with tasks"
echo "============================================"
