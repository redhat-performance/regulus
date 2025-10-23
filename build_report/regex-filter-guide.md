# 🔍 Regex Filter - Usage Guide

## Basic Usage

### Simple Text Search
Just type any text to find rows containing that text (case-insensitive):

```
tcp        → Shows all rows containing "tcp" anywhere
iperf      → Shows rows with "iperf"
success    → Shows successful tests
failed     → Shows failed tests
200        → Shows rows containing "200"
```

---

## Pattern Matching with Regex

### Find Multiple Terms (OR)
Use the pipe `|` character:

```
tcp|udp              → Rows with "tcp" OR "udp"
200|500|1000         → Rows with 200, 500, or 1000
success|passed       → Successful or passed tests
failed|error|timeout → Any problems
iperf|netperf        → Either benchmark
```

### Start of Text (^)
Match only at the beginning:

```
^test               → Rows starting with "test"
^benchmark_cpu      → Rows starting with "benchmark_cpu"
^File               → Rows starting with "File" (column name)
```

### End of Text ($)
Match only at the end:

```
\.log$              → Rows ending with ".log"
Mbps$               → Rows ending with "Mbps"
success$            → Rows ending with "success"
```

### Wildcard Matching (.)
The dot `.` matches any single character:

```
t.p                 → Matches "tcp", "tap", "tip"
200.Mbps            → Matches "200Mbps", "200 Mbps"
test.network        → Matches "test_network", "test-network"
```

### Multiple Characters (.*)
The `.*` matches any characters (zero or more):

```
tcp.*200            → "tcp" followed by "200" anywhere after
protocol.*tcp       → "protocol" followed by "tcp" somewhere
success.*iperf      → Successful iperf tests
test.*\.log         → "test" followed by ".log" anywhere
```

---

## Common Use Cases

### Filter by Protocol
```
tcp                  → All TCP tests
udp                  → All UDP tests
tcp|udp              → Both protocols
protocol.*tcp        → Rows with "protocol" and "tcp"
```

### Filter by Status
```
success              → All successful tests
failed               → All failed tests
failed|error         → Any failures or errors
success.*tcp         → Successful TCP tests only
```

### Filter by Benchmark
```
iperf                → All iperf tests
iperf3               → Only iperf3 tests
sysbench             → Sysbench tests
fio                  → FIO disk tests
iperf|netperf        → Network benchmarks
```

### Filter by Performance Values
```
\d+Mbps              → Any throughput value (e.g., "200Mbps", "1000Mbps")
[5-9]\d{2}Mbps       → 500-999 Mbps (high performance)
[1-4]\d{2}Mbps       → 100-499 Mbps (medium performance)
\d+\.\d+             → Any decimal number (e.g., "99.5", "200.3")
```

### Filter by Configuration
```
3,2,linear           → Specific config pattern
pods.*4              → Configs with 4 pods
topo.*mesh           → Mesh topology tests
scale.*2             → Scale factor 2
```

### Filter by File Names
```
^test_network        → Files starting with "test_network"
\.log$               → All .log files
test_network_\d+     → Files like "test_network_01", "test_network_42"
^benchmark_.*        → Files starting with "benchmark_"
```

### Complex Queries
```
tcp.*success.*200              → Successful TCP tests at 200Mbps
^test_network.*iperf.*success  → test_network files with successful iperf
(tcp|udp).*[5-9]\d{2}Mbps      → TCP or UDP with 500+ Mbps
protocol.*(tcp|udp).*success   → Successful tests for either protocol
```

---

## Special Characters Reference

### Characters that Need Escaping
If you want to search for these literally, add `\` before them:

```
\.    → Literal dot (e.g., "file.log")
\*    → Literal asterisk
\+    → Literal plus sign
\?    → Literal question mark
\(    → Literal opening parenthesis
\)    → Literal closing parenthesis
\[    → Literal opening bracket
\]    → Literal closing bracket
\$    → Literal dollar sign
\^    → Literal caret
\|    → Literal pipe
```

Examples:
```
file\.log            → Matches "file.log" (not "fileXlog")
\$100                → Matches "$100"
192\.168\.1\.1       → Matches IP address "192.168.1.1"
```

### Quantifiers
```
*     → 0 or more times    (e.g., "te*st" matches "tst", "test", "teest")
+     → 1 or more times    (e.g., "te+st" matches "test", "teest", not "tst")
?     → 0 or 1 time        (e.g., "colou?r" matches "color" or "colour")
{n}   → Exactly n times    (e.g., "\d{3}" matches "123", not "12" or "1234")
{n,}  → n or more times    (e.g., "\d{2,}" matches "12", "123", "1234")
{n,m} → Between n and m    (e.g., "\d{2,4}" matches "12", "123", "1234")
```

### Character Classes
```
\d    → Any digit (0-9)
\w    → Any word character (a-z, A-Z, 0-9, _)
\s    → Any whitespace (space, tab, newline)
.     → Any character except newline

[abc]    → Any of: a, b, or c
[^abc]   → NOT a, b, or c
[a-z]    → Any lowercase letter
[A-Z]    → Any uppercase letter
[0-9]    → Any digit
[a-zA-Z] → Any letter
```

Examples:
```
\d+                  → One or more digits: "123", "42"
\w+                  → One or more word chars: "test", "file_01"
test_\d+             → "test_" followed by numbers: "test_01", "test_123"
[tT]cp               → "tcp" or "Tcp"
[0-9]{3}             → Exactly 3 digits: "200", "500"
```

---

## Real-World Examples

### Scenario 1: Debug Failed Tests
**Goal:** Find all tests that failed

```
Filter: failed|error|timeout

Result: Shows only rows with failures
```

### Scenario 2: Find High-Performance Tests
**Goal:** Find tests with throughput >= 500 Mbps

```
Filter: [5-9]\d{2}Mbps|[1-9]\d{3}Mbps

Result: Matches 500-999 Mbps and 1000+ Mbps
```

### Scenario 3: Compare TCP vs UDP
**Goal:** Find all TCP tests, then all UDP tests

```
First filter: ^.*tcp
(Review results)

Second filter: ^.*udp
(Compare)
```

### Scenario 4: Find Specific Test Runs
**Goal:** Find test_network files from run 10-19

```
Filter: test_network_(1[0-9])

Result: Matches test_network_10 through test_network_19
```

### Scenario 5: Find Tests with Packet Loss
**Goal:** Find any mention of packet loss

```
Filter: packet.*loss|loss.*\d+%

Result: Shows rows mentioning packet loss
```

### Scenario 6: Filter by Date Pattern
**Goal:** Find tests from October 2024

```
Filter: 2024-10-\d{2}

Result: Matches dates like "2024-10-15", "2024-10-23"
```

### Scenario 7: Find Specific Configurations
**Goal:** Find tests with 4 pods and linear topology

```
Filter: pods.*4.*linear|linear.*pods.*4

Result: Matches either order
```

### Scenario 8: Exclude Certain Tests
**Goal:** Show everything EXCEPT sysbench tests

```
Filter: ^(?!.*sysbench).*

Result: Shows all rows that don't contain "sysbench"
```

---

## Keyboard Shortcuts

```
Enter      → Apply filter immediately (skips 300ms delay)
Escape     → Clear filter and show all rows
```

---

## Visual Feedback

### Match Count Display
- **Green text**: Results found (e.g., "Showing 12 of 203 rows")
- **Red text**: No matches found (e.g., "Showing 0 of 203 rows")
- **Empty**: No filter applied

### Input Border Colors
- **Blue border**: Input is focused (ready to type)
- **Red border**: Invalid regex pattern (will use plain text search instead)
- **Gray border**: Normal state

### Error Messages
When you enter invalid regex, you'll see:
```
⚠️ Invalid regex pattern - using plain text search
```
The filter still works, but searches for plain text instead.

---

## Tips & Tricks

### 1. Start Simple, Then Add Complexity
```
Step 1: tcp              → See all TCP tests
Step 2: tcp.*success     → Narrow to successful ones
Step 3: tcp.*success.*200 → Further narrow to 200Mbps
```

### 2. Use OR for Quick Comparisons
```
200|500|1000    → See multiple throughput levels at once
```

### 3. Test Your Pattern First
If unsure about a pattern, test it on https://regex101.com first

### 4. Case Doesn't Matter (By Default)
```
TCP, tcp, Tcp    → All match the same rows
```

### 5. Partial Matches Work
```
"net" matches:
  - network
  - netperf
  - test_network
  - 192.168.1.1/24
```

### 6. Clear Filter to See Original Data
Press Escape or click "Clear" to return to full view

### 7. Match Count Helps Validate
If match count is 0, your pattern might be too specific

---

## Common Mistakes to Avoid

### ❌ Forgetting to Escape Special Characters
**Wrong:** `file.log` (matches "file.log" AND "fileXlog")
**Right:** `file\.log` (matches only "file.log")

### ❌ Using Quotes
**Wrong:** `"tcp"` (searches for literal quotes + tcp)
**Right:** `tcp` (searches for tcp)

### ❌ Overly Complex Patterns
**Complex:** `^(?=.*tcp)(?=.*success)(?=.*200).*$`
**Simple:** `tcp.*success.*200` (does the same thing)

### ❌ Not Using .* Between Terms
**Wrong:** `tcpsuccess` (looks for "tcpsuccess" together)
**Right:** `tcp.*success` (looks for tcp followed by success)

---

## Quick Reference Card

### Most Useful Patterns
```
SEARCH FOR          | PATTERN
--------------------|---------------------------
Exact text          | tcp
Multiple options    | tcp|udp
Numbers             | \d+
Any characters      | .*
Start of line       | ^test
End of line         | \.log$
Text + text         | tcp.*success
3 digits            | \d{3}
Range (500-999)     | [5-9]\d{2}
Not containing X    | ^(?!.*text).*
```

### Common Searches
```
All errors          → failed|error|timeout
High performance    → [5-9]\d{2}Mbps
Specific benchmark  → iperf|netperf|fio
Config pattern      → 3,2,linear
File names          → ^test_network_\d+
Success + protocol  → success.*(tcp|udp)
```

---

## Advanced: Lookahead/Lookbehind

### Positive Lookahead (?=...)
Match if followed by something:
```
tcp(?=.*success)     → "tcp" only if "success" appears later
\d+(?=Mbps)          → Numbers only before "Mbps"
```

### Negative Lookahead (?!...)
Match if NOT followed by something:
```
^(?!.*failed).*      → Rows that don't contain "failed"
tcp(?!.*error)       → "tcp" only if "error" doesn't appear
```

### Positive Lookbehind (?<=...)
Match if preceded by something:
```
(?<=tcp).*200        → "200" only if "tcp" appears before
(?<=success).*Mbps   → Throughput only in successful tests
```

---

## Practice Exercises

Try these patterns and see what you get:

1. Find all tests with throughput over 100 Mbps
   ```
   [1-9]\d{2,}Mbps
   ```

2. Find TCP tests that passed
   ```
   tcp.*success|success.*tcp
   ```

3. Find test files numbered 5-9
   ```
   test_\d*[5-9]
   ```

4. Find any benchmark except sysbench
   ```
   ^(?!.*sysbench).*benchmark
   ```

5. Find tests with packet loss mentioned
   ```
   (packet|loss)
   ```

---

## Need Help?

If a pattern isn't working:
1. Try simpler pattern first (just the word)
2. Check if you need to escape special characters
3. Look at the match count - 0 means too specific
4. Check error message - red border means invalid regex
5. Use plain text search if regex is too complex

Remember: You can always clear the filter and start over!

---

**Happy filtering! 🔍**
