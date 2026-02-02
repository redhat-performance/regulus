#!/usr/bin/env python3
"""
Dashboard CLI - Command-line interface for the performance dashboard.

Launch the web-based dashboard to visualize and analyze performance reports.
"""

import argparse
import sys
from pathlib import Path

# Add parent directory to path to import from build_report modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from dashboard import create_app


def main():
    """Main entry point for the dashboard CLI."""
    parser = argparse.ArgumentParser(
        description='Performance Benchmark Dashboard - Visualize and analyze benchmark reports',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Launch dashboard with reports from current directory
  python run_dashboard.py

  # Specify reports directory
  python run_dashboard.py --reports /path/to/reports

  # Use custom port
  python run_dashboard.py --port 8080

  # Enable debug mode
  python run_dashboard.py --debug

  # Specify host and port
  python run_dashboard.py --host 0.0.0.0 --port 5000
        """
    )

    parser.add_argument(
        '--reports',
        type=str,
        default='.',
        help='Directory containing JSON report files (default: current directory)'
    )

    parser.add_argument(
        '--host',
        type=str,
        default='0.0.0.0',
        help='Host to bind to (default: 0.0.0.0)'
    )

    parser.add_argument(
        '--port',
        type=int,
        default=5000,
        help='Port to listen on (default: 5000)'
    )

    parser.add_argument(
        '--debug',
        action='store_true',
        help='Enable debug mode (auto-reload on code changes)'
    )

    args = parser.parse_args()

    # Validate reports directory
    reports_path = Path(args.reports)
    if not reports_path.exists():
        print(f"Error: Reports directory does not exist: {args.reports}")
        sys.exit(1)

    if not reports_path.is_dir():
        print(f"Error: Not a directory: {args.reports}")
        sys.exit(1)

    # Check for JSON files
    json_files = list(reports_path.glob('*.json'))
    json_files = [f for f in json_files if not f.name.endswith('_schema.json')]

    if not json_files:
        print(f"Warning: No JSON report files found in {args.reports}")
        print("The dashboard will start, but no data will be displayed.")
        response = input("Continue anyway? [y/N]: ")
        if response.lower() != 'y':
            sys.exit(0)

    # Create and run the dashboard app
    print("\n" + "="*70)
    print("Performance Benchmark Dashboard")
    print("="*70)

    app = create_app(
        reports_dir=str(reports_path.absolute()),
        host=args.host,
        port=args.port
    )

    print("\nStarting dashboard server...")
    print(f"Access the dashboard at: http://{args.host}:{args.port}")
    print("Press Ctrl+C to stop the server")
    print("="*70 + "\n")

    try:
        app.run(debug=args.debug)
    except KeyboardInterrupt:
        print("\n\nShutting down dashboard...")
        sys.exit(0)


if __name__ == '__main__':
    main()
