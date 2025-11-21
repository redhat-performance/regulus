# Dashboard Functionality Test Checklist

Use this checklist to verify all dashboard features are working correctly with the mockup data.

## Pre-Test Setup

- [ ] Run the test script: `./dashboard/test_data/run_dashboard_test.sh`
- [ ] Dashboard starts without errors
- [ ] Browser opens to http://localhost:5000 (or your IP:5000)
- [ ] Summary cards show:
  - [ ] Total Reports: **7**
  - [ ] Total Results: **10**
  - [ ] Benchmark Types: **3**
  - [ ] Date Range: **Jan 14, 2025 - Jan 19, 2025**

---

## Test 1: Overview Tab (Default View)

### Summary Cards
- [ ] All 4 summary cards display correct values

### Performance by Datapath Model Chart
- [ ] Chart shows 4 bars (OVNK, DPU, SRIOV, MACVLAN)
- [ ] OVNK has highest average (~92 Gbps)
- [ ] Values make sense visually

### Performance by Kernel Chart
- [ ] Chart shows 2 bars (5.14.0-570, 5.14.0-580)
- [ ] Both kernels show performance data
- [ ] Newer kernel (580) should show slightly better average

### Top 10 Performers Table
- [ ] Table shows at least 10 rows
- [ ] Rank #1 is: OVNK, CX7, kernel 580, **97.8 Gbps**
- [ ] Rank #2 is: OVNK, CX7, kernel 570, **95.4 Gbps**
- [ ] Table shows: Rank, Benchmark, Datapath, NIC, Kernel, Topology, Mean, Unit, CPU%
- [ ] All values populated (no blanks)

**Status**: ⬜ PASS / ⬜ FAIL

---

## Test 2: Filter Functionality

### Individual Filters

#### Filter: Benchmark
- [ ] Dropdown shows: iperf, trafficgen, uperf
- [ ] Select "uperf" → Overview updates
- [ ] Top performers shows only uperf results

#### Filter: Datapath
- [ ] Dropdown shows: DPU, MACVLAN, OVNK, SRIOV
- [ ] Select "OVNK" → Shows 3 configurations (2x CX7, 1x CX6)
- [ ] Top performers updates to show only OVNK

#### Filter: NIC
- [ ] Dropdown shows: CX6, CX7, E810, E910
- [ ] Select "CX7" → Shows 3 results (2x OVNK, 1x DPU)

#### Filter: Architecture
- [ ] Dropdown shows: emerald_rapid, ice_lake, sapphire_rapids
- [ ] Select "emerald_rapid" → Shows 5 results

#### Filter: Protocol
- [ ] Dropdown shows: tcp, udp
- [ ] Select "tcp" → Filters results correctly

#### Filter: Test Type
- [ ] Dropdown shows: bidirec, pps, rr, stream
- [ ] Select "stream" → Shows only stream tests

#### Filter: CPU
- [ ] Dropdown shows: 112, 40, 58
- [ ] Select "58" → Shows emerald_rapid results

#### Filter: Kernel
- [ ] Dropdown shows: 5.14.0-570.49.1, 5.14.0-580.12.1
- [ ] Select "5.14.0-570" → Shows 3 results

#### Filter: RCOS
- [ ] Dropdown shows: 4.16, 4.17
- [ ] Select "4.16" → Filters correctly

#### Filter: Topology
- [ ] Dropdown shows: internode, intranode
- [ ] Select "intranode" → Shows intranode tests only

#### Filter: Performance
- [ ] Dropdown shows: balanced, performance, powersave, tuned
- [ ] Select "tuned" → Shows OVNK results

#### Filter: Offload
- [ ] Dropdown shows: off, on
- [ ] Select "on" → Filters correctly

### Combined Filters
- [ ] Set: Datapath=OVNK, NIC=CX7
  - Expected: 2 results (files from Jan 15 and Jan 19)
  - Top performer: 97.8 Gbps
- [ ] Set: Model=DPU, Architecture=sapphire_rapids
  - Expected: 1 result (CX6 config)
  - Performance: 88.5 Gbps
- [ ] Set: Benchmark=uperf, Test-Type=rr
  - Expected: 3 results with transaction/sec metrics

### Clear All Button
- [ ] Click "Clear All" button
- [ ] All filters reset to "All"
- [ ] Overview shows all data again

**Status**: ⬜ PASS / ⬜ FAIL

---

## Test 3: Trends Tab

### Access Trends Tab
- [ ] Click "Trends" tab
- [ ] Tab becomes active
- [ ] Chart loads

### No Grouping
- [ ] Group By: "No Grouping"
- [ ] Chart shows single line with all results over time (Jan 14-19)
- [ ] Line shows data points across the date range

### Group by Model
- [ ] Select "Group by Model"
- [ ] Chart shows 4 lines (OVNK, DPU, SRIOV, MACVLAN)
- [ ] Legend shows all 4 models
- [ ] OVNK line is highest
- [ ] Each line has appropriate data points

### Group by Kernel
- [ ] Select "Group by Kernel"
- [ ] Chart shows 2 lines (5.14.0-570, 5.14.0-580)
- [ ] Both lines display correctly
- [ ] Newer kernel trend visible

### Group by Topology
- [ ] Select "Group by Topology"
- [ ] Chart shows 2 lines (intranode, internode)
- [ ] Intranode generally higher

### With Filters
- [ ] Set Filter: Model=OVNK
- [ ] Group by NIC
- [ ] Chart shows 2 lines (CX6, CX7)
- [ ] CX7 line higher than CX6
- [ ] CX7 shows improvement from Jan 15 to Jan 19

**Status**: ⬜ PASS / ⬜ FAIL

---

## Test 4: Comparison Tab

### Basic Comparison Setup
- [ ] Click "Comparison" tab
- [ ] Tab becomes active
- [ ] Three dropdowns visible: Compare Field, Value A, Value B
- [ ] "Compare" button visible

### Comparison Test 1: NIC (CX6 vs CX7) for OVNK
**Setup:**
- [ ] Filter: Model=OVNK, Benchmark=uperf
- [ ] Compare Field: NIC Vendor
- [ ] Value A: CX6
- [ ] Value B: CX7
- [ ] Click "Compare"

**Results:**
- [ ] Comparison results appear
- [ ] Shows mean for CX6: ~82.6 Gbps
- [ ] Shows mean for CX7: ~95-98 Gbps
- [ ] Shows difference: ~13-15 Gbps
- [ ] Shows percentage: ~15-18%
- [ ] Indicates CX7 is better

### Comparison Test 2: Model (OVNK vs DPU)
**Setup:**
- [ ] Clear filters
- [ ] Compare Field: Datapath Model
- [ ] Value A: OVNK
- [ ] Value B: DPU
- [ ] Click "Compare"

**Results:**
- [ ] Shows OVNK average: ~92 Gbps
- [ ] Shows DPU average: ~89 Gbps
- [ ] Shows which is better
- [ ] Percentage difference calculated

### Comparison Test 3: Kernel Versions
**Setup:**
- [ ] Filter: Model=OVNK, NIC=CX7
- [ ] Compare Field: Kernel
- [ ] Value A: 5.14.0-570.49.1.el9_6.x86_64
- [ ] Value B: 5.14.0-580.12.1.el9_7.x86_64
- [ ] Click "Compare"

**Results:**
- [ ] Shows kernel 570: 95.4 Gbps
- [ ] Shows kernel 580: 97.8 Gbps
- [ ] Shows ~2.4 Gbps improvement
- [ ] Shows ~2.5% improvement
- [ ] Indicates newer kernel is better

### Comparison Test 4: Architecture
**Setup:**
- [ ] Clear filters
- [ ] Compare Field: Architecture
- [ ] Value A: ice_lake
- [ ] Value B: emerald_rapid
- [ ] Click "Compare"

**Results:**
- [ ] Shows ice_lake average: ~78 Gbps
- [ ] Shows emerald_rapid average: ~85-90 Gbps
- [ ] Shows emerald_rapid is better
- [ ] Percentage calculated correctly

**Status**: ⬜ PASS / ⬜ FAIL

---

## Test 5: Results Table Tab

### Basic Table Display
- [ ] Click "Results Table" tab
- [ ] Tab becomes active
- [ ] DataTable loads with all results
- [ ] Columns visible: Benchmark, Datapath, NIC, Kernel, Topology, Protocol, Test Type, Mean, StdDev, CPU%, Timestamp
- [ ] Multiple pages if > 25 results
- [ ] Pagination controls work

### Sorting
- [ ] Click "Mean" column header
- [ ] Table sorts by Mean (ascending)
- [ ] Click again → sorts descending
- [ ] Top row shows 97.8 Gbps (OVNK CX7)
- [ ] Click "CPU%" column → sorts by CPU usage

### Searching
- [ ] Use search box at top right
- [ ] Type "stream" → filters to stream test types
- [ ] Clear search → all results return
- [ ] Type "CX7" → filters to CX7 results
- [ ] Search works across all columns

### Filtering + Table
- [ ] Set Filter: Model=DPU
- [ ] Results Table updates to show only DPU rows
- [ ] Row count updates
- [ ] Can still search within filtered results
- [ ] Clear filter → all results return

### Column Details
- [ ] Timestamp column shows dates correctly
- [ ] Mean column shows decimal values (e.g., 95.40)
- [ ] StdDev shows variation
- [ ] CPU% shows percentage values
- [ ] All values align properly

**Status**: ⬜ PASS / ⬜ FAIL

---

## Test 6: Cross-Tab Filter Consistency

- [ ] Set filters in Overview tab (e.g., Model=OVNK)
- [ ] Switch to Trends tab → filter still applied
- [ ] Switch to Comparison tab → filter still applied
- [ ] Switch to Results Table → filter still applied
- [ ] Clear filters in one tab → clears across all tabs

**Status**: ⬜ PASS / ⬜ FAIL

---

## Test 7: Reload Reports Button

- [ ] Click "Reload Reports" button (top right)
- [ ] Confirmation popup appears
- [ ] Reports reload successfully
- [ ] Summary statistics update
- [ ] No errors in console

**Status**: ⬜ PASS / ⬜ FAIL

---

## Test 8: Data Accuracy Verification

### Verify Top Performers
- [ ] Top performer is OVNK + CX7 + emerald_rapid + kernel 580 = **97.8 Gbps**
- [ ] Second is OVNK + CX7 + emerald_rapid + kernel 570 = **95.4 Gbps**
- [ ] Third is DPU + CX7 + emerald_rapid = **92.1 Gbps**

### Verify Model Averages (Overview Chart)
Calculate and verify:
- [ ] OVNK average: (97.8 + 95.4 + 82.6) / 3 = **~92 Gbps**
- [ ] DPU average: (92.1 + 88.5) / 2 = **~90 Gbps**
- [ ] SRIOV average: **78.3 Gbps**
- [ ] MACVLAN average: **72.5 Gbps**

### Verify NIC vs NIC Comparison
With filter Model=OVNK, Benchmark=uperf, Test-Type=stream:
- [ ] CX6 mean: **82.6 Gbps**
- [ ] CX7 mean: **(95.4 + 97.8) / 2 = 96.6 Gbps**
- [ ] Difference: **14 Gbps (~17% improvement)**

**Status**: ⬜ PASS / ⬜ FAIL

---

## Test 9: Edge Cases

### Empty Filter Combination
- [ ] Set filters that return no results (e.g., Model=SRIOV + NIC=CX7)
- [ ] Dashboard handles gracefully (shows "No data" or empty charts)
- [ ] No JavaScript errors

### Single Result Filter
- [ ] Filter to single result (e.g., Model=MACVLAN)
- [ ] Charts still render
- [ ] Trends show single point
- [ ] No errors

**Status**: ⬜ PASS / ⬜ FAIL

---

## Test 10: Browser Console Check

- [ ] Open browser developer console (F12)
- [ ] Check for JavaScript errors
- [ ] Check for failed API requests (Network tab)
- [ ] All API endpoints return 200 OK
- [ ] No CORS errors
- [ ] No missing resources (404s)

**Status**: ⬜ PASS / ⬜ FAIL

---

## Overall Test Summary

| Test Category | Status |
|---------------|--------|
| 1. Overview Tab | ⬜ PASS / ⬜ FAIL |
| 2. Filters | ⬜ PASS / ⬜ FAIL |
| 3. Trends Tab | ⬜ PASS / ⬜ FAIL |
| 4. Comparison Tab | ⬜ PASS / ⬜ FAIL |
| 5. Results Table | ⬜ PASS / ⬜ FAIL |
| 6. Cross-Tab Filters | ⬜ PASS / ⬜ FAIL |
| 7. Reload Reports | ⬜ PASS / ⬜ FAIL |
| 8. Data Accuracy | ⬜ PASS / ⬜ FAIL |
| 9. Edge Cases | ⬜ PASS / ⬜ FAIL |
| 10. Console Errors | ⬜ PASS / ⬜ FAIL |

**Overall Result**: ⬜ ALL TESTS PASS / ⬜ SOME FAILURES

---

## Issues Found

Document any issues found during testing:

```
Issue #1:
- Component: [e.g., Trends Tab]
- Description: [What went wrong]
- Expected: [What should happen]
- Actual: [What actually happened]
- Severity: [Critical/Major/Minor]

Issue #2:
...
```

---

## Notes

Additional observations or comments:

```
[Your notes here]
```
