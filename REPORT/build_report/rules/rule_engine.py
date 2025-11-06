"""
Rule engine for managing extraction rules.

Handles benchmark-specific rule sets and rule management.
"""

from typing import Dict, List
import json
from pathlib import Path

from ..interfaces.protocols import RuleEngineInterface
from ..models.data_models import BenchmarkRuleSet, ExtractionRule


class ConfigurableRuleEngine:
    """Rule engine with configurable rule sets."""
    
    def __init__(self):
        self.rulesets: Dict[str, BenchmarkRuleSet] = {}
        self._initialize_default_rules()
    
    def _initialize_default_rules(self):
        """Initialize with default rule sets."""
        # Default rules
        default_rules = BenchmarkRuleSet(
            benchmark_name="default",
            rules=[
                ExtractionRule("benchmark", r"benchmark:\s*(.+)"),
                ExtractionRule("run-id", r"run-id:\s*(.+)"),
                ExtractionRule("result", r"result:\s*(.+)")
            ]
        )
        
        # Trafficgen-specific rules
        trafficgen_rules = BenchmarkRuleSet(
            benchmark_name="trafficgen",
            rules=[
                ExtractionRule("benchmark", r"benchmark:\s*(.+)"),
                ExtractionRule("run-id", r"run-id:\s*(.+)"),
                ExtractionRule("period_length", r"period length:\s*(.+)"),
                ExtractionRule("result", r"result:\s*\(([^)]+)\)\s*samples:\s*([0-9.]+)\s*mean:\s*([0-9.]+)\s*min:\s*([0-9.]+)\s*max:\s*([0-9.]+)", "trafficgen_result")
            ],
            metadata_rules=[
                ExtractionRule("tags", r"tags:\s*(.+)"),
                ExtractionRule("iteration-id", r"iteration-id:\s*(.+)"),
                ExtractionRule("sample-id", r"sample-id:\s*(.+)"),
                ExtractionRule("period_range_begin", r"begin:\s*(\d+)"),
                ExtractionRule("period_range_end", r"end:\s*(\d+)")
            ]
        )
        
        self.rulesets["default"] = default_rules
        self.rulesets["trafficgen"] = trafficgen_rules
    
    def get_rules_for_benchmark(self, benchmark: str) -> BenchmarkRuleSet:
        """Get rules for a specific benchmark."""
        return self.rulesets.get(benchmark, self.rulesets["default"])
    
    def add_benchmark_rules(self, ruleset: BenchmarkRuleSet) -> None:
        """Add or update rules for a benchmark."""
        self.rulesets[ruleset.benchmark_name] = ruleset
    
    def list_available_benchmarks(self) -> List[str]:
        """List all available benchmark rule sets."""
        return list(self.rulesets.keys())
    
    def remove_benchmark_rules(self, benchmark_name: str) -> bool:
        """Remove rules for a benchmark."""
        if benchmark_name in self.rulesets and benchmark_name != "default":
            del self.rulesets[benchmark_name]
            return True
        return False


class FileBasedRuleEngine(ConfigurableRuleEngine):
    """Rule engine that can load rules from configuration files."""
    
    def __init__(self, config_dir: str = "rules/config"):
        super().__init__()
        self.config_dir = Path(config_dir)
        self.config_dir.mkdir(parents=True, exist_ok=True)
        self._load_rules_from_files()
    
    def _load_rules_from_files(self):
        """Load rules from JSON configuration files."""
        for config_file in self.config_dir.glob("*.json"):
            try:
                self._load_ruleset_from_file(config_file)
            except Exception as e:
                print(f"Error loading rules from {config_file}: {e}")
    
    def _load_ruleset_from_file(self, config_file: Path):
        """Load a single ruleset from a configuration file."""
        with open(config_file, 'r', encoding='utf-8') as f:
            config = json.load(f)
        
        rules = [
            ExtractionRule(
                field_name=rule["field_name"],
                pattern=rule["pattern"],
                processor=rule.get("processor")
            )
            for rule in config.get("rules", [])
        ]
        
        metadata_rules = None
        if "metadata_rules" in config:
            metadata_rules = [
                ExtractionRule(
                    field_name=rule["field_name"],
                    pattern=rule["pattern"],
                    processor=rule.get("processor")
                )
                for rule in config["metadata_rules"]
            ]
        
        ruleset = BenchmarkRuleSet(
            benchmark_name=config["benchmark_name"],
            rules=rules,
            metadata_rules=metadata_rules
        )
        
        self.add_benchmark_rules(ruleset)
        print(f"Loaded rules for benchmark: {config['benchmark_name']}")
    
    def save_ruleset_to_file(self, benchmark_name: str) -> bool:
        """Save a ruleset to a configuration file."""
        if benchmark_name not in self.rulesets:
            return False
        
        ruleset = self.rulesets[benchmark_name]
        config = {
            "benchmark_name": ruleset.benchmark_name,
            "rules": [
                {
                    "field_name": rule.field_name,
                    "pattern": rule.pattern,
                    "processor": rule.processor
                }
                for rule in ruleset.rules
            ]
        }
        
        if ruleset.metadata_rules:
            config["metadata_rules"] = [
                {
                    "field_name": rule.field_name,
                    "pattern": rule.pattern,
                    "processor": rule.processor
                }
                for rule in ruleset.metadata_rules
            ]
        
        config_file = self.config_dir / f"{benchmark_name}.json"
        try:
            with open(config_file, 'w', encoding='utf-8') as f:
                json.dump(config, f, indent=2)
            print(f"Saved rules for {benchmark_name} to {config_file}")
            return True
        except Exception as e:
            print(f"Error saving rules for {benchmark_name}: {e}")
            return False


class DynamicRuleEngine(ConfigurableRuleEngine):
    """Rule engine with runtime rule modification capabilities."""
    
    def __init__(self):
        super().__init__()
        self._rule_change_callbacks = []
    
    def add_rule_to_benchmark(self, benchmark_name: str, rule: ExtractionRule, is_metadata: bool = False) -> bool:
        """Add a single rule to an existing benchmark."""
        if benchmark_name not in self.rulesets:
            # Create new benchmark ruleset
            self.rulesets[benchmark_name] = BenchmarkRuleSet(
                benchmark_name=benchmark_name,
                rules=[],
                metadata_rules=[]
            )
        
        ruleset = self.rulesets[benchmark_name]
        
        if is_metadata:
            if ruleset.metadata_rules is None:
                ruleset.metadata_rules = []
            ruleset.metadata_rules.append(rule)
        else:
            ruleset.rules.append(rule)
        
        self._notify_rule_change(benchmark_name, "add", rule)
        return True
    
    def remove_rule_from_benchmark(self, benchmark_name: str, field_name: str, is_metadata: bool = False) -> bool:
        """Remove a rule from a benchmark."""
        if benchmark_name not in self.rulesets:
            return False
        
        ruleset = self.rulesets[benchmark_name]
        rules_list = ruleset.metadata_rules if is_metadata else ruleset.rules
        
        if rules_list is None:
            return False
        
        for i, rule in enumerate(rules_list):
            if rule.field_name == field_name:
                removed_rule = rules_list.pop(i)
                self._notify_rule_change(benchmark_name, "remove", removed_rule)
                return True
        
        return False
    
    def add_rule_change_callback(self, callback):
        """Add a callback function to be called when rules change."""
        self._rule_change_callbacks.append(callback)
    
    def _notify_rule_change(self, benchmark_name: str, action: str, rule: ExtractionRule):
        """Notify callbacks about rule changes."""
        for callback in self._rule_change_callbacks:
            try:
                callback(benchmark_name, action, rule)
            except Exception as e:
                print(f"Error in rule change callback: {e}")
