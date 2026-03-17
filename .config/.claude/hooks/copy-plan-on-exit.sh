#!/usr/bin/env bash
# Copies the most recently modified plan file to a slugified name
# derived from its "# Plan: ..." title line.

PLANS_DIR="$HOME/.claude/plans"

# Find the most recently modified .md file
latest=$(ls -t "$PLANS_DIR"/*.md 2>/dev/null | head -1)
[ -z "$latest" ] && exit 0

# Extract title from first line: "# Plan: Some Title Here" -> "Some Title Here"
title=$(head -1 "$latest" | sed -n 's/^# *//p')
[ -z "$title" ] && exit 0

# Slugify: lowercase, replace non-alphanumeric with hyphens, collapse, trim
slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
[ -z "$slug" ] && exit 0

timestamp=$(date +%Y%m%d-%H%M%S)
target="$PLANS_DIR/${slug}-${timestamp}.md"

# Skip if source already has a timestamped descriptive name
basename=$(basename "$latest" .md)
echo "$basename" | grep -qE '[0-9]{8}-[0-9]{6}$' && exit 0

cp "$latest" "$target"
