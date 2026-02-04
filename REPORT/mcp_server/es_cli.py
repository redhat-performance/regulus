#!/usr/bin/env python3
"""
Regulus ElasticSearch CLI - Standalone command-line interface

This wraps the MCP server tools to provide a simple CLI without needing Claude Desktop.

Usage:
    ./es_cli.py list-batches
    ./es_cli.py batch-info <batch_id>
    ./es_cli.py search --benchmark uperf --model OVNK
    ./es_cli.py compare <batch_id_1> <batch_id_2>
    ./es_cli.py delete <batch_id>
    ./es_cli.py stats
"""

import os
import sys
import asyncio
import argparse

# Import the MCP server tools
from regulus_es_mcp import (
    list_batches,
    get_batch_info,
    search_benchmarks,
    compare_batches,
    delete_batch,
    get_index_stats
)


async def main():
    parser = argparse.ArgumentParser(
        description='Regulus ElasticSearch CLI',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s list-batches
  %(prog)s batch-info f2c533ef-b020-473e-babf-b81371e8147b
  %(prog)s search --benchmark uperf --model OVNK --nic E810
  %(prog)s search --execution-label non-accelerated --model DPU
  %(prog)s search --execution-label baseline-q1 --min-throughput 90
  %(prog)s compare batch1-uuid batch2-uuid
  %(prog)s delete batch-uuid
  %(prog)s stats

Environment Variables:
  ES_URL    - ElasticSearch URL (required)
  ES_INDEX  - ElasticSearch index name (default: regulus-results)
        """
    )

    subparsers = parser.add_subparsers(dest='command', help='Command to execute')

    # list-batches
    subparsers.add_parser('list-batches', help='List all upload batches')

    # batch-info
    batch_info_parser = subparsers.add_parser('batch-info', help='Get batch details')
    batch_info_parser.add_argument('batch_id', help='Batch UUID')

    # search
    search_parser = subparsers.add_parser('search', help='Search benchmarks')
    search_parser.add_argument('--benchmark', help='Benchmark type (uperf, iperf, etc.)')
    search_parser.add_argument('--model', help='Datapath model (OVNK, DPU, SRIOV, etc.)')
    search_parser.add_argument('--nic', help='NIC type (E810, CX6, CX7, BF3, etc.)')
    search_parser.add_argument('--topology', help='Topology (intranode, internode)')
    search_parser.add_argument('--protocol', help='Protocol (tcp, udp)')
    search_parser.add_argument('--test-type', dest='test_type', help='Test type (stream, rr, crr)')
    search_parser.add_argument('--kernel', help='Kernel version')
    search_parser.add_argument('--rcos', help='RCOS/OpenShift version')
    search_parser.add_argument('--arch', help='Architecture')
    search_parser.add_argument('--cpu', help='CPU count')
    search_parser.add_argument('--performance-profile', dest='performance_profile', help='Performance profile')
    search_parser.add_argument('--offload', help='Offload setting (on, off)')
    search_parser.add_argument('--threads', type=int, help='Thread count')
    search_parser.add_argument('--wsize', type=int, help='Write size')
    search_parser.add_argument('--rsize', type=int, help='Read size')
    search_parser.add_argument('--pods-per-worker', dest='pods_per_worker', type=int, help='Pods per worker')
    search_parser.add_argument('--scale-out-factor', dest='scale_out_factor', type=int, help='Scale out factor')
    search_parser.add_argument('--execution-label', dest='execution_label', help='Execution label (e.g., baseline-q1, non-accelerated, weekly-run-2025-w01)')
    search_parser.add_argument('--run-id', dest='run_id', help='Run ID (exact match)')
    search_parser.add_argument('--iteration-id', dest='iteration_id', help='Iteration ID (exact match)')
    search_parser.add_argument('--min-throughput', type=float, help='Minimum throughput')
    search_parser.add_argument('--max-throughput', type=float, help='Maximum throughput')
    search_parser.add_argument('--size', type=int, default=10, help='Number of results (default: 10)')

    # compare
    compare_parser = subparsers.add_parser('compare', help='Compare two batches')
    compare_parser.add_argument('batch_id_1', help='First batch UUID')
    compare_parser.add_argument('batch_id_2', help='Second batch UUID')

    # delete
    delete_parser = subparsers.add_parser('delete', help='Delete a batch')
    delete_parser.add_argument('batch_id', help='Batch UUID to delete')
    delete_parser.add_argument('--yes', action='store_true', help='Skip confirmation')

    # stats
    subparsers.add_parser('stats', help='Show index statistics')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    # Verify ES_URL is set
    if not os.getenv('ES_URL'):
        print("Error: ES_URL environment variable not set", file=sys.stderr)
        sys.exit(1)

    # Execute command
    try:
        if args.command == 'list-batches':
            result = await list_batches()

        elif args.command == 'batch-info':
            result = await get_batch_info(args.batch_id)

        elif args.command == 'search':
            result = await search_benchmarks(
                benchmark=args.benchmark,
                model=args.model,
                nic=args.nic,
                topology=args.topology,
                protocol=args.protocol,
                test_type=args.test_type,
                kernel=args.kernel,
                rcos=args.rcos,
                arch=args.arch,
                cpu=args.cpu,
                performance_profile=args.performance_profile,
                offload=args.offload,
                threads=args.threads,
                wsize=args.wsize,
                rsize=args.rsize,
                pods_per_worker=args.pods_per_worker,
                scale_out_factor=args.scale_out_factor,
                min_throughput=args.min_throughput,
                max_throughput=args.max_throughput,
                execution_label=args.execution_label,
                run_id=args.run_id,
                iteration_id=args.iteration_id,
                size=args.size
            )

        elif args.command == 'compare':
            result = await compare_batches(args.batch_id_1, args.batch_id_2)

        elif args.command == 'delete':
            confirm = "yes" if args.yes else "no"
            result = await delete_batch(args.batch_id, confirm)

            # If confirmation needed, prompt user
            if "WARNING" in result and not args.yes:
                print(result)
                print()
                response = input("Confirm deletion? Type 'yes' to proceed: ")
                if response == 'yes':
                    result = await delete_batch(args.batch_id, confirm='yes')
                else:
                    result = "Deletion cancelled"

        elif args.command == 'stats':
            result = await get_index_stats()

        else:
            parser.print_help()
            sys.exit(1)

        print(result)

    except Exception as e:
        print("Error: {}".format(str(e)), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    asyncio.run(main())
