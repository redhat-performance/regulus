#!/bin/sh

echo "stopping ru"
tmux kill-session -t ru 2>/dev/null || true
echo "ru stopped"
