#!/usr/bin/env python3
"""
Wrapper script to run the dashboard without interactive prompts.
Changes to data directory and auto-continues even when no data found.
"""
import sys
import os

# Change to data directory so dashboard finds JSON files
os.chdir('/app/data')

# Mock the input function to auto-respond "y"
def mock_input(prompt):
    print(prompt + "y (auto-continued in container mode)")
    return "y"

# Replace built-in input with our mock
__builtins__.input = mock_input

# Add dashboard to path
sys.path.insert(0, '/app/dashboard')

# Import and run the dashboard
import run_dashboard
run_dashboard.main()
