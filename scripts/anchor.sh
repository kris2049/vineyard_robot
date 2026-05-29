#!/bin/bash
# Cognitive Anchor — run at start of every dev session
# Ensures all agents share the same current understanding of the project.
# Usage: ./scripts/anchor.sh

set -e
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "╔══════════════════════════════════════╗"
echo "║  🧠 Cognitive Anchor — Vineyard Mower║"
echo "╚══════════════════════════════════════╝"

echo ""
echo "─── Git Status ───"
BRANCH=$(git branch --show-current)
COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo "0")
echo "  Branch: $BRANCH | Commits: $COMMITS"

echo ""
echo "─── CodeGraph Status ───"
codegraph status 2>/dev/null | grep -E "(Files:|Nodes:|Edges:|Index)" || echo "  ⚠️  CodeGraph not available — run 'codegraph index'"

echo ""
echo "─── Recent Changes ───"
git log --oneline -5 2>/dev/null || echo "  No commits yet"

echo ""
echo "─── Subsystem File Count ───"
for dir in src/motion_control src/perception src/navigation src/mission_planner src/diagnostics src/data_pipeline; do
    count=$(find "$dir" -name "*.py" ! -name "__init__.py" 2>/dev/null | wc -l)
    printf "  %-25s %2d source files\n" "$dir:" "$count"
done
echo "  $(find src/common -name '*.py' ! -name '__init__.py' 2>/dev/null | wc -l) common types"

echo ""
echo "─── Test Count ───"
test_count=$(find tests -name "test_*.py" 2>/dev/null | wc -l)
echo "  $test_count test files"

echo ""
echo "Cognitive anchor complete. Ready for development."
