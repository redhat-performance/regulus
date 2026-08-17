# Design: Using Template

## Context

The current `analyze-batch.py` generates a full Orion YAML config per fingerprint
at runtime. The team prefers a static template file, consistent with how other
Orion users (e.g., kube-burner) work. This design adds a static Jinja2 template
that receives fingerprint values via `--input-vars`.

## How It Works Today

```
ES mapping → build fingerprint dict → generate full YAML → orion --config full.yaml
```

Every field value is baked into a generated YAML. No template, no input-vars.

## Proposed Change

```
fingerprint dict → json.dumps() → orion --config template.yaml --input-vars '{"benchmark":"uperf",...}'
```

A static `template.yaml` with `{{ }}` placeholders replaces per-fingerprint YAML
generation. The fingerprint dict (already in memory) is serialized to JSON and
passed via `--input-vars` on the CLI. No intermediate file is written.

### Precedent

Same pattern used by kube-burner's Prow step (`openshift-qe-orion-commands.sh`):
```bash
CLUSTER_METADATA=$(./ocp-metadata | jq -c .)
EXTRA_FLAGS+=" --input-vars=${CLUSTER_METADATA}"
orion --config ${ORION_CONFIG} ${EXTRA_FLAGS}
```

Kube-burner gets metadata from the `ocp-metadata` binary.
Regulus gets it from `analyze-batch.py` which reads fingerprint values from ES.

## Static File: `configs/template.yaml`

One test entry with `{{ }}` for all fingerprint fields.
Uses `{% if field is defined %}` for fields that may be removed by IGNORE.

```yaml
tests:
  - name: fingerprint-{{ fp_index }}
    timestamp: '@timestamp'
    uuid_field: iteration_id
    metadata:
{% if benchmark is defined %}
      benchmark: {{ benchmark }}
{% endif %}
{% if model is defined %}
      model: {{ model }}
{% endif %}
{% if topology is defined %}
      topology: {{ topology }}
{% endif %}
{% if protocol is defined %}
      protocol: {{ protocol }}
{% endif %}
{% if nic is defined %}
      nic: {{ nic }}
{% endif %}
{% if ipv is defined %}
      ipv: '{{ ipv }}'
{% endif %}
{% if test_type is defined %}
      test_type: {{ test_type }}
{% endif %}
{% if threads is defined %}
      threads: {{ threads }}
{% endif %}
{% if wsize is defined %}
      wsize: {{ wsize }}
{% endif %}
{% if rsize is defined %}
      rsize: {{ rsize }}
{% endif %}
{% if performance_profile is defined %}
      performance_profile: {{ performance_profile }}
{% endif %}
{% if offload is defined %}
      offload: {{ offload }}
{% endif %}
{% if kernel is defined %}
      kernel: {{ kernel }}
{% endif %}
{% if rcos is defined %}
      rcos: {{ rcos }}
{% endif %}
{% if arch is defined %}
      arch: {{ arch }}
{% endif %}
{% if cpu is defined %}
      cpu: '{{ cpu }}'
{% endif %}
{% if pods_per_worker is defined %}
      pods_per_worker: '{{ pods_per_worker }}'
{% endif %}
{% if scale_out_factor is defined %}
      scale_out_factor: '{{ scale_out_factor }}'
{% endif %}
    metrics:
      - name: throughput
        metric_of_interest: mean
        agg: {agg_type: avg}
        direction: 0
        threshold: 5
        labels: ['[Batch: {{ batch_id }}]']
      - name: cpu_cost
        metric_of_interest: busy_cpu
        agg: {agg_type: avg}
        direction: 0
        threshold: 10
        labels: ['[Batch: {{ batch_id }}]']
```

All fields use `{% if is defined %}` so any field can be passed in IGNORE
without crashing Orion. Fields not in `--input-vars` are undefined in
Jinja2's StrictUndefined mode — without the guard, Orion crashes.

## IGNORE Handling

IGNORE removes fields from the fingerprint. With templates, ignored fields are
absent from `--input-vars`, so Jinja2 sees them as undefined.

```
active_fields = all_fields - IGNORE
fingerprint = {field: value for field in active_fields}
input_vars = json.dumps(fingerprint)
```

Example with `IGNORE="rcos kernel"`:
- `rcos` and `kernel` are NOT in the fingerprint dict
- NOT in `--input-vars`
- Template's `{% if rcos is defined %}` skips the rcos line
- Orion queries ES without rcos/kernel filters → cross-version analysis

## Startup Check: Template vs Mapping Drift

At startup, compare the template's `{{ }}` placeholders against the fields
in the ES index. If a field exists in the index but not in the template,
fail loud:

```python
template_fields = set(re.findall(r'\{\{\s*(\w+)\s*\}\}', template_text))
index_fields = set(fingerprint_fields)

missing = index_fields - template_fields
if missing:
    print(f"WARNING: Template is behind ES index! Missing fields: {missing}")
    print(f"Update template.yaml to include these fields.")
    sys.exit(2)
```

This catches the case where a new field is added to the ES index but the
template hasn't been updated yet. Without this check, the new field would
be silently ignored and Orion could match wrong documents.

## Call Stack Diff

```diff
 analyze-batch.py
   ├─ __init__()
-  │   └─ GET {es_index}/_mapping
-  │       → discover fingerprint fields (subtract NON_FINGERPRINT_FIELDS)
+  │   ├─ GET {es_index}/_mapping
+  │   │   → determine fingerprint fields (subtract NON_FINGERPRINT_FIELDS)
+  │   └─ read configs/template.yaml
+  │       → compare {{ }} placeholders against index fields
+  │       → exit(2) if index has fields not in template
   │
   ├─ analyze()
   │   │                                    (unchanged)
   │   ├─ query_tests()
   │   │                                    (unchanged)
   │   ├─ group_by_fingerprint()
   │   │
   │   └─ FOR EACH fingerprint:
   │       │
-  │       ├─ generate_orion_config(fingerprint)
-  │       │   └─ write YAML with all metadata values + 2 metrics
-  │       │       → generated-configs/orion-config-XXXX.yaml
-  │       │
   │       └─ run_orion_analysis()
   │           └─ _build_orion_cmd()
-  │               └─ orion --config orion-config-XXXX.yaml ...
+  │               ├─ json.dumps(fingerprint)
+  │               └─ orion --config configs/template.yaml \
+  │                        --input-vars '{"benchmark":"uperf","threads":64,...}'
```

Three changes:
1. **`__init__()`** — adds template read + drift check
2. **`generate_orion_config()`** — deleted entirely
3. **`_build_orion_cmd()`** — static template + `--input-vars` replaces generated config

## 2-Way Sync Requirement

This design introduces a maintenance contract:

1. **Template placeholders** — `{{ field }}` in `template.yaml`
2. **ES index fields** — whatever fields exist in the index

When a new field is added to the ES index, someone must add `{{ new_field }}`
to the template. The startup drift check catches this, but the fix is manual.

