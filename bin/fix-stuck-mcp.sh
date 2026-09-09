#!/bin/bash
# fix-stuck-mcp.sh - Survey, diagnose, and (optionally) recover a MachineConfigPool that is
# stuck DEGRADED/UPDATING because its nodes reference a rendered MachineConfig that was
# deleted (e.g. a half-finished PAO/MCP cleanup, or a branch switch between features that
# share the same worker nodes).
#
# MODES
#   (default)     Survey the cluster + diagnose every pool (READ-ONLY), then print the
#                 remediation PLAN as a dry-run. Nothing is changed.
#   --diagnose    Survey + diagnose only, then stop. Pure read-only. (alias: --survey)
#   --apply       Survey + diagnose, then actually perform the safe recovery.
#
# THE SAFE, AUTOMATABLE CASE
#   A node's currentConfig/desiredConfig points at  rendered-<pool>-<HASH>  which no longer
#   exists. Because <HASH> is a *content* hash, ANY existing  rendered-<other>-<HASH>  is
#   byte-identical to the missing one. We recreate the missing MC by cloning that identical
#   donor. The MCD then finds its config, clears Degraded, and reconciles to the pool's
#   desired rendered config with NO drain and NO reboot. Afterwards we delete the recreated
#   orphan once no node references it.
#
# It intentionally does NOT delete MCPs, remove node labels, or touch PerformanceProfiles
# -- that is teardown policy, not recovery. Use `make cleanup` for teardown.
#
# See skill: recover-stuck-mcp-cleanup.md
#
# Usage:
#   fix-stuck-mcp.sh [options]
#     -s, --survey        Survey + diagnose only (read-only), then stop. (alias: --diagnose)
#     -p, --pool NAME     Restrict to this MCP (repeatable). Default: all pools.
#     -a, --apply         Perform the safe recovery. Default: survey + dry-run plan only.
#     -t, --timeout SEC   Seconds to wait for pool reconcile after apply. Default: 600.
#     -k, --keep-orphan   Do not delete the recreated MC after nodes move off it.
#     -h, --help          This help.
#
# Requires: a working `oc` (export KUBECONFIG first).

set -uo pipefail

APPLY=false
DIAGNOSE_ONLY=false
KEEP_ORPHAN=false
TIMEOUT=600
POOLS=()

die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "[fix-stuck-mcp] $*"; }
hr()   { printf '%s\n' "------------------------------------------------------------"; }
run()  {  # echo + (maybe) execute
    echo "  \$ $*"
    if $APPLY; then "$@"; else echo "    (dry-run: not executed)"; fi
}

usage() {
    sed -n 's/^# \{0,1\}//p' "$0" | sed -n '/^fix-stuck-mcp.sh - /,/^Requires:/p'
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        -s|--survey|--diagnose) DIAGNOSE_ONLY=true; shift;;
        -p|--pool)      POOLS+=("$2"); shift 2;;
        -a|--apply)     APPLY=true; shift;;
        -t|--timeout)   TIMEOUT="$2"; shift 2;;
        -k|--keep-orphan) KEEP_ORPHAN=true; shift;;
        -h|--help)      usage 0;;
        *) die "unknown option: $1 (see --help)";;
    esac
done
$DIAGNOSE_ONLY && APPLY=false   # --survey always wins over --apply

command -v oc >/dev/null 2>&1 || die "oc not found in PATH"
command -v jq >/dev/null 2>&1 || die "jq not found in PATH"
oc get mcp >/dev/null 2>&1 || die "cannot reach cluster. Export KUBECONFIG (e.g. /root/mno/kubeconfig) and retry."

# ---------- helpers -------------------------------------------------------------------
mc_exists() { oc get mc "$1" >/dev/null 2>&1; }

pool_cond() {   # pool, conditionType -> status (True/False/"")
    oc get mcp "$1" -o json | jq -r --arg t "$2" \
        '[.status.conditions[]? | select(.type==$t) | .status][0] // ""'
}

pool_degrade_msg() {  # concatenated messages from any *Degraded* condition that is True
    oc get mcp "$1" -o json | jq -r \
        '[.status.conditions[]? | select(.status=="True" and (.type|test("Degraded"))) | .message]
         | join(" ")'
}

pool_nodes() {  # nodes selected by the pool's nodeSelector.matchLabels
    local pool="$1" sel
    sel=$(oc get mcp "$pool" -o json | jq -r \
        '(.spec.nodeSelector.matchLabels // {}) | to_entries | map("\(.key)=\(.value)") | join(",")')
    [ -z "$sel" ] && return 0
    oc get nodes -l "$sel" -o jsonpath='{.items[*].metadata.name}'
}

node_anno() {   # node, shortkey (e.g. currentConfig) -> value
    oc get node "$1" -o jsonpath="{.metadata.annotations.machineconfiguration\.openshift\.io/$2}" 2>/dev/null
}

find_donor() {  # missing-mc-name -> prints an identical existing donor MC name, if any
    local mc="$1" hash="${1##*-}"
    echo "$hash" | grep -qE '^[a-f0-9]{32}$' || return 1
    oc get mc -o name 2>/dev/null | sed 's#^machineconfig.*/##' \
        | grep -E "^rendered-.*-${hash}$" | grep -v -x "$mc" | head -1
}

# Collect the set of missing rendered MCs a pool's nodes reference (via stdout, one/line)
pool_missing_mcs() {
    local pool="$1" n field mc
    { for n in $(pool_nodes "$pool"); do
        for field in currentConfig desiredConfig; do
            mc=$(node_anno "$n" "$field"); [ -z "$mc" ] && continue
            mc_exists "$mc" || echo "$mc"
        done
      done
      pool_degrade_msg "$pool" | grep -oE 'rendered-[a-zA-Z0-9._-]+' \
        | while read -r mc; do mc_exists "$mc" || echo "$mc"; done
    } | sort -u
}

# Classify a pool -> sets globals: CLASS (HEALTHY|UPDATING|DEGRADED_MISSING_MC|DEGRADED_OTHER)
classify_pool() {
    local pool="$1" up upd deg
    up=$(pool_cond "$pool" Updated); upd=$(pool_cond "$pool" Updating); deg=$(pool_cond "$pool" Degraded)
    if [ "$deg" = "True" ]; then
        if pool_degrade_msg "$pool" | grep -q "missing MachineConfig"; then CLASS=DEGRADED_MISSING_MC
        else CLASS=DEGRADED_OTHER; fi
    elif [ "$upd" = "True" ]; then CLASS=UPDATING
    elif [ "$up" = "True" ]; then CLASS=HEALTHY
    else CLASS=UPDATING; fi
}

# ---------- pool list -----------------------------------------------------------------
if [ "${#POOLS[@]}" -eq 0 ]; then
    mapfile -t POOLS < <(oc get mcp -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | sort)
fi

# ====================== SURVEY (always, read-only) ====================================
echo
hr; info "CLUSTER SURVEY  ($(date '+%Y-%m-%d %H:%M:%S'))"; hr
echo "MachineConfigPools:"
oc get mcp
echo
echo "Nodes:"
oc get nodes
echo
echo "machine-config clusteroperator:"
oc get co machine-config
echo

# ====================== PER-POOL DIAGNOSIS (read-only) ================================
UNHEALTHY=0
INPROGRESS=0
AUTO_FIXABLE=()   # pools this script can safely remediate

for POOL in "${POOLS[@]}"; do
    oc get mcp "$POOL" >/dev/null 2>&1 || { echo "[$POOL] does not exist, skipping"; continue; }
    hr
    classify_pool "$POOL"
    read -r mcount ready updated degraded < <(oc get mcp "$POOL" -o json | jq -r \
        '[.status.machineCount,.status.readyMachineCount,.status.updatedMachineCount,.status.degradedMachineCount]|@tsv')
    cfg=$(oc get mcp "$POOL" -o jsonpath='{.status.configuration.name}')
    echo "Pool: $POOL   [$CLASS]"
    echo "  desired config : ${cfg:-<none>}"
    echo "  machines       : total=$mcount ready=$ready updated=$updated degraded=$degraded"

    # reference counter (explains the tangle / who owns the pool)
    refs=$(oc get mcp "$POOL" -o jsonpath="{.metadata.annotations.feature\.openshift\.io/references}" 2>/dev/null)
    rcnt=$(oc get mcp "$POOL" -o jsonpath="{.metadata.annotations.feature\.openshift\.io/reference-count}" 2>/dev/null)
    [ -n "${refs}${rcnt}" ] && echo "  feature refs   : count=${rcnt:-0} refs=[${refs:-}]"

    # node-level view (skip for healthy pools to reduce noise)
    if [ "$CLASS" != "HEALTHY" ]; then
        for n in $(pool_nodes "$POOL"); do
            cur=$(node_anno "$n" currentConfig); des=$(node_anno "$n" desiredConfig)
            st=$(node_anno "$n" state)
            nstat=$(oc get node "$n" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
            sched=$(oc get node "$n" -o jsonpath='{.spec.unschedulable}' 2>/dev/null)
            cflag=""; mc_exists "$cur" || cflag=" (MISSING!)"
            dflag=""; mc_exists "$des" || dflag=" (MISSING!)"
            echo "  node $n: state=$st ready=$nstat${sched:+ cordoned=$sched}"
            echo "      current=${cur}${cflag}"
            echo "      desired=${des}${dflag}"
        done
    fi

    # diagnosis + recommendation
    case "$CLASS" in
      HEALTHY)
        echo "  DIAGNOSIS: healthy (Updated, not Degraded, not Updating)." ;;
      UPDATING)
        echo "  DIAGNOSIS: IN PROGRESS -- updating and NOT degraded (normal install/reboot)."
        echo "  ACTION   : nothing to fix; wait and re-run --survey to confirm it settles."
        INPROGRESS=$((INPROGRESS+1)) ;;
      DEGRADED_OTHER)
        echo "  DIAGNOSIS: DEGRADED for a reason other than a missing rendered MC:"
        echo "             $(pool_degrade_msg "$POOL")"
        echo "  ACTION   : this script does NOT auto-fix this. Inspect manually"
        echo "             (see recover-stuck-mcp-cleanup skill)."
        UNHEALTHY=$((UNHEALTHY+1)) ;;
      DEGRADED_MISSING_MC)
        echo "  DIAGNOSIS: DEGRADED because nodes reference a deleted rendered MachineConfig."
        echo "             Typical cause: a prior pool teardown (or branch switch) removed a"
        echo "             rendered-*-<HASH> that these nodes still point at."
        mapfile -t miss < <(pool_missing_mcs "$POOL")
        fixable=true
        for mc in "${miss[@]}"; do
            donor=$(find_donor "$mc" || true)
            if [ -n "$donor" ]; then
                echo "    missing: $mc   ->  identical donor available: $donor  [AUTO-FIXABLE]"
            else
                echo "    missing: $mc   ->  NO identical donor found          [MANUAL]"
                fixable=false
            fi
        done
        if $fixable && [ "${#miss[@]}" -gt 0 ]; then
            echo "  ACTION   : recoverable with NO reboot -- recreate the missing MC(s) from the"
            echo "             identical donor, then let the pool reconcile. Run: --apply"
            AUTO_FIXABLE+=("$POOL")
        else
            echo "  ACTION   : no safe donor for some missing MC(s); manual recovery required."
        fi
        UNHEALTHY=$((UNHEALTHY+1)) ;;
    esac
done
hr

# Summary line
echo
if [ "$UNHEALTHY" -eq 0 ] && [ "$INPROGRESS" -eq 0 ]; then
    info "SUMMARY: all pools healthy. Nothing to fix."
elif [ "$UNHEALTHY" -eq 0 ]; then
    info "SUMMARY: $INPROGRESS pool(s) updating in progress (not degraded); nothing to fix. Re-check later."
else
    extra=""; [ "$INPROGRESS" -gt 0 ] && extra=", $INPROGRESS updating in progress"
    info "SUMMARY: $UNHEALTHY pool(s) need attention${extra}; auto-fixable: [${AUTO_FIXABLE[*]:-none}]"
fi

if $DIAGNOSE_ONLY; then
    exit $([ "$UNHEALTHY" -eq 0 ] && echo 0 || echo 1)
fi

# ====================== REMEDIATION (dry-run unless --apply) ==========================
if [ "${#AUTO_FIXABLE[@]}" -eq 0 ]; then
    info "No auto-fixable pools. Exiting without changes."
    exit $([ "$UNHEALTHY" -eq 0 ] && echo 0 || echo 1)
fi

echo
hr; info "REMEDIATION PLAN$([ "$APPLY" = false ] && echo ' (DRY-RUN -- re-run with --apply to execute)')"; hr
OVERALL_RC=0

for POOL in "${AUTO_FIXABLE[@]}"; do
    echo
    info "===== Recovering pool: $POOL ====="
    RECREATED=()
    mapfile -t miss < <(pool_missing_mcs "$POOL")
    for mc in "${miss[@]}"; do
        donor=$(find_donor "$mc" || true)
        [ -z "$donor" ] && { echo "  skip $mc (no donor)"; OVERALL_RC=1; continue; }
        echo "  Recreate '$mc' from identical donor '$donor'"
        if $APPLY; then
            oc get mc "$donor" -o json \
              | jq --arg n "$mc" 'del(.metadata.uid,.metadata.resourceVersion,
                    .metadata.creationTimestamp,.metadata.ownerReferences,
                    .metadata.generation,.status) | .metadata.name=$n' \
              | oc create -f - || { echo "  ERROR: create failed for $mc"; OVERALL_RC=1; continue; }
        else
            echo "    \$ oc get mc $donor -o json | jq '...rename to $mc...' | oc create -f -"
            echo "    (dry-run: not executed)"
        fi
        RECREATED+=("$mc")
    done

    if $APPLY && [ "${#RECREATED[@]}" -gt 0 ]; then
        info "  Waiting up to ${TIMEOUT}s for '$POOL' to reconcile..."
        deadline=$(( $(date +%s) + TIMEOUT ))
        while :; do
            up=$(pool_cond "$POOL" Updated); upd=$(pool_cond "$POOL" Updating); deg=$(pool_cond "$POOL" Degraded)
            echo "    Updated=$up Updating=$upd Degraded=$deg"
            [ "$up" = "True" ] && [ "$deg" = "False" ] && { info "  Pool '$POOL' recovered."; break; }
            [ "$(date +%s)" -ge "$deadline" ] && { echo "  TIMEOUT waiting for '$POOL'."; OVERALL_RC=1; break; }
            sleep 10
        done
    fi

    if [ "${#RECREATED[@]}" -gt 0 ] && ! $KEEP_ORPHAN; then
        for mc in "${RECREATED[@]}"; do
            still=""
            for n in $(pool_nodes "$POOL"); do
                for field in currentConfig desiredConfig; do
                    [ "$(node_anno "$n" "$field")" = "$mc" ] && still="$n/$field"
                done
            done
            if [ -n "$still" ]; then
                echo "  Keep orphan '$mc' (still referenced by $still)."
            else
                echo "  Delete recreated orphan '$mc' (no node references it)."
                run oc delete mc "$mc"
            fi
        done
    fi
done

echo
info "Post-remediation machine-config operator status:"
oc get co machine-config
echo
$APPLY && info "Done (rc=$OVERALL_RC)." || info "Dry-run complete. Re-run with --apply to execute the plan."
exit "$OVERALL_RC"
