#!/usr/bin/env python3
"""
Generate mock Regulus test data for development and testing.

Provides RegulusMockDataGenerator with methods to create realistic test data
with various performance patterns (stable, regression, improvement, etc.).
"""

import json
import uuid
import random
import sys
import os
from datetime import datetime, timedelta
from typing import List, Dict, Any


class RegulusMockDataGenerator:

    def __init__(self, base_timestamp=None, batch_id=None):
        """Initialize with base timestamp (default: 30 days ago) and optional batch_id."""
        if base_timestamp is None:
            base_timestamp = datetime.utcnow() - timedelta(days=30)
        self.base_timestamp = base_timestamp
        self.batch_id = batch_id or str(uuid.uuid4())

        self.baselines = {
            'throughput': {'mean': 8.5, 'stddev': 0.3, 'unit': 'Gbps', 'benchmark': 'uperf'},
            'transactions': {'mean': 15000, 'stddev': 500, 'unit': 'transactions-sec', 'benchmark': 'uperf'},
            'connections': {'mean': 50000, 'stddev': 2000, 'unit': 'connections-sec', 'benchmark': 'uperf'},
            'latency': {'mean': 0.45, 'stddev': 0.05, 'unit': 'ms', 'benchmark': 'uperf'},
        }

    def _generate_base_document(self, metric_type, timestamp, test_config=None):
        """Generate base document structure matching real Regulus data."""
        baseline = self.baselines[metric_type]
        doc = {
            '@timestamp': timestamp.strftime('%Y-%m-%dT%H:%M:%S.%f'),
            'batch_id': self.batch_id,
            'regulus_git_branch': 'main',
            'execution_label': 'default',
            'regulus_data': '1_GROUP/NO-PAO/4IP/INTER-NODE/TCP/2-POD/run-MOCK-' +
                            timestamp.strftime('%Y-%m-%d-%H:%M:%S') + '/result-summary.txt',
            'run_id': str(uuid.uuid4()),
            'iteration_id': str(uuid.uuid4()),
            'benchmark': test_config.get('benchmark', 'uperf') if test_config else 'uperf',
            'test_type': 'stream',
            'protocol': test_config.get('protocol', 'tcp') if test_config else 'tcp',
            'model': 'OVNK',
            'nic': test_config.get('nic', 'X550') if test_config else 'X550',
            'arch': 'Intel(R)_Xeon(R)_Gold_6130_CPU_@_2.10GHz',
            'cpu': test_config.get('cpu', '4') if test_config else '4',
            'kernel': test_config.get('kernel', '5.14.0-503.11.1.el9_5.x86_64') if test_config else '5.14.0-503.11.1.el9_5.x86_64',
            'rcos': test_config.get('rcos', '9.6.20260615-0') if test_config else '9.6.20260615-0',
            'topology': test_config.get('topology', 'internode') if test_config else 'internode',
            'performance_profile': test_config.get('performance_profile', 'None') if test_config else 'None',
            'offload': 'None',
            'threads': test_config.get('threads', 64) if test_config else 64,
            'wsize': test_config.get('wsize', 32768) if test_config else 32768,
            'pods_per_worker': test_config.get('pods_per_worker', '1') if test_config else '1',
            'scale_out_factor': test_config.get('scale_out_factor', '1') if test_config else '1',
            'ipv': test_config.get('ipv', '4') if test_config else '4',
            'unit': baseline['unit'],
            'busy_cpu': round(random.gauss(25.0, 2.0), 2),
            'mock_data': True,
        }

        if test_config:
            for key in ('@timestamp', 'batch_id', 'regulus_git_branch', 'execution_label',
                        'regulus_data', 'run_id', 'iteration_id', 'benchmark', 'test_type',
                        'protocol', 'model', 'nic', 'arch', 'cpu', 'kernel', 'rcos',
                        'topology', 'performance_profile', 'offload', 'threads', 'wsize',
                        'pods_per_worker', 'scale_out_factor', 'unit', 'busy_cpu', 'mock_data',
                        'ipv'):
                if key in test_config and key not in ('@timestamp', 'batch_id', 'run_id',
                                                       'iteration_id', 'unit', 'mock_data'):
                    doc[key] = test_config[key]

        return doc

    def _add_noise(self, value, stddev):
        """Add Gaussian noise to a value."""
        return max(0, random.gauss(value, stddev))

    def generate_stable_baseline(self, metric_type='throughput', num_samples=30, test_config=None):
        """Generate stable baseline data (no regressions).

        Timestamps are spread across seconds/minutes for time series analysis.
        """
        if test_config is None:
            test_config = {'topology': 'internode', 'protocol': 'tcp'}

        baseline = self.baselines[metric_type]
        documents = []

        for i in range(num_samples):
            timestamp = self.base_timestamp + timedelta(seconds=i * 30)
            doc = self._generate_base_document(metric_type, timestamp, test_config)
            doc['mean'] = self._add_noise(baseline['mean'], baseline['stddev'])
            doc['min'] = doc['mean'] * 0.95
            doc['max'] = doc['mean'] * 1.05
            doc['stddev'] = baseline['stddev']
            doc['sample_count'] = random.randint(100, 200)
            documents.append(doc)

        return documents

    def generate_sudden_regression(self, metric_type='throughput', num_baseline=30,
                                    num_regressed=5, regression_pct=0.25, test_config=None):
        """Generate data with sudden performance regression.

        Timestamps are spread across seconds/minutes for time series analysis.
        """
        if test_config is None:
            test_config = {'topology': 'internode', 'protocol': 'tcp'}

        baseline = self.baselines[metric_type]
        documents = []

        for i in range(num_baseline):
            timestamp = self.base_timestamp + timedelta(seconds=i * 30)
            doc = self._generate_base_document(metric_type, timestamp, test_config)
            doc['mean'] = self._add_noise(baseline['mean'], baseline['stddev'])
            doc['min'] = doc['mean'] * 0.95
            doc['max'] = doc['mean'] * 1.05
            doc['stddev'] = baseline['stddev']
            doc['sample_count'] = random.randint(100, 200)
            documents.append(doc)

        new_mean = baseline['mean'] * (1 - regression_pct)
        for i in range(num_regressed):
            timestamp = self.base_timestamp + timedelta(seconds=(num_baseline + i) * 30)
            doc = self._generate_base_document(metric_type, timestamp, test_config)
            doc['mean'] = self._add_noise(new_mean, baseline['stddev'])
            doc['min'] = doc['mean'] * 0.95
            doc['max'] = doc['mean'] * 1.05
            doc['stddev'] = baseline['stddev']
            doc['sample_count'] = random.randint(100, 200)
            documents.append(doc)

        return documents

    def generate_gradual_degradation(self, metric_type='throughput', num_samples=30,
                                      total_degradation_pct=0.30, test_config=None):
        """Generate data with gradual performance degradation.

        Timestamps are spread across days for time series analysis.
        """
        if test_config is None:
            test_config = {'topology': 'pod-to-pod', 'protocol': 'tcp'}

        baseline = self.baselines[metric_type]
        documents = []
        degradation_per_sample = total_degradation_pct / num_samples

        for i in range(num_samples):
            timestamp = self.base_timestamp + timedelta(seconds=i * 30)
            doc = self._generate_base_document(metric_type, timestamp, test_config)
            current_degradation = degradation_per_sample * (i + 1)
            current_mean = baseline['mean'] * (1 - current_degradation)
            doc['mean'] = self._add_noise(current_mean, baseline['stddev'] * 0.5)
            doc['min'] = doc['mean'] * 0.95
            doc['max'] = doc['mean'] * 1.05
            doc['stddev'] = baseline['stddev']
            doc['sample_count'] = random.randint(100, 200)
            documents.append(doc)

        return documents

    def generate_performance_improvement(self, metric_type='throughput', num_baseline=30,
                                          num_improved=5, improvement_pct=0.20, test_config=None):
        """Generate data with performance improvement (e.g., after optimization).

        Timestamps are spread across days for time series analysis.
        """
        if test_config is None:
            test_config = {'topology': 'internode', 'protocol': 'udp'}

        baseline = self.baselines[metric_type]
        documents = []

        for i in range(num_baseline):
            timestamp = self.base_timestamp + timedelta(seconds=i * 30)
            doc = self._generate_base_document(metric_type, timestamp, test_config)
            doc['mean'] = self._add_noise(baseline['mean'], baseline['stddev'])
            doc['min'] = doc['mean'] * 0.95
            doc['max'] = doc['mean'] * 1.05
            doc['stddev'] = baseline['stddev']
            doc['sample_count'] = random.randint(100, 200)
            documents.append(doc)

        new_mean = baseline['mean'] * (1 + improvement_pct)
        for i in range(num_improved):
            timestamp = self.base_timestamp + timedelta(seconds=(num_baseline + i) * 30)
            doc = self._generate_base_document(metric_type, timestamp, test_config)
            doc['mean'] = self._add_noise(new_mean, baseline['stddev'])
            doc['min'] = doc['mean'] * 0.95
            doc['max'] = doc['mean'] * 1.05
            doc['stddev'] = baseline['stddev']
            doc['sample_count'] = random.randint(100, 200)
            documents.append(doc)

        return documents

    def generate_intermittent_issues(self, metric_type='throughput', num_samples=30,
                                      num_outliers=5, outlier_drop_pct=0.50, test_config=None):
        """Generate data with intermittent outliers (should NOT trigger detection).

        Timestamps are spread across days for time series analysis.
        """
        if test_config is None:
            test_config = {'topology': 'internode', 'protocol': 'tcp', 'nic': 'mlx5_1'}

        baseline = self.baselines[metric_type]
        documents = []
        outlier_positions = random.sample(range(num_samples), min(num_outliers, num_samples))

        for i in range(num_samples):
            timestamp = self.base_timestamp + timedelta(seconds=i * 30)
            doc = self._generate_base_document(metric_type, timestamp, test_config)
            if i in outlier_positions:
                doc['mean'] = baseline['mean'] * (1 - outlier_drop_pct)
            else:
                doc['mean'] = self._add_noise(baseline['mean'], baseline['stddev'] * 0.5)
            doc['min'] = doc['mean'] * 0.95
            doc['max'] = doc['mean'] * 1.05
            doc['stddev'] = baseline['stddev']
            doc['sample_count'] = random.randint(100, 200)
            documents.append(doc)

        return documents

    def generate_multi_metric_scenario(self, num_samples=30, test_config=None):
        """Generate data for multiple metrics (throughput, transactions, connections).

        Timestamps are spread across days for time series analysis.
        """
        if test_config is None:
            test_config = {'topology': 'internode', 'protocol': 'tcp', 'threads': 4}

        documents = []

        for metric_type in ('throughput', 'transactions', 'connections'):
            baseline = self.baselines[metric_type]
            for i in range(num_samples):
                timestamp = self.base_timestamp + timedelta(seconds=i * 30)
                doc = self._generate_base_document(metric_type, timestamp, test_config)
                if i >= num_samples - 2:
                    doc['mean'] = baseline['mean'] * 0.8
                else:
                    doc['mean'] = self._add_noise(baseline['mean'], baseline['stddev'])
                doc['min'] = doc['mean'] * 0.95
                doc['max'] = doc['mean'] * 1.05
                doc['stddev'] = baseline['stddev']
                doc['sample_count'] = random.randint(100, 200)
                documents.append(doc)

        return documents


def main():
    gen = RegulusMockDataGenerator()

    print("Generating stable baseline...")
    docs = gen.generate_stable_baseline()
    print(f"  Generated {len(docs)} documents")

    print("Generating sudden regression...")
    docs = gen.generate_sudden_regression()
    print(f"  Generated {len(docs)} documents")

    print("Generating gradual degradation...")
    docs = gen.generate_gradual_degradation()
    print(f"  Generated {len(docs)} documents")

    print("Generating performance improvement...")
    docs = gen.generate_performance_improvement()
    print(f"  Generated {len(docs)} documents")

    print("Generating intermittent issues...")
    docs = gen.generate_intermittent_issues()
    print(f"  Generated {len(docs)} documents")

    print("Generating multi-metric scenario...")
    docs = gen.generate_multi_metric_scenario()
    print(f"  Generated {len(docs)} documents")

    print("\nDone!")


if __name__ == '__main__':
    main()
