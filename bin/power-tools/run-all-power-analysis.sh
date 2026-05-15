#!/bin/bash
OUTPUT="all-power-view.txt"
cd /home/hnhan/NVD-DPU/nvd-44-test-power-regulus

echo "POWER ANALYSIS REPORT" > "$OUTPUT"
echo "Generated: $(date)" >> "$OUTPUT"
echo "=" | awk '{for(i=1;i<=100;i++) printf "="}' >> "$OUTPUT"
echo "" >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "1. SUMMARY" >> "$OUTPUT"
echo "==========" >> "$OUTPUT"
python3 bin/analyze-power.py summary >> "$OUTPUT" 2>&1
echo "" >> "$OUTPUT"

echo "2. BY SERVER" >> "$OUTPUT"
echo "============" >> "$OUTPUT"
python3 bin/analyze-power.py by-server >> "$OUTPUT" 2>&1
echo "" >> "$OUTPUT"

echo "3. NIC BREAKDOWN" >> "$OUTPUT"
echo "================" >> "$OUTPUT"
python3 bin/analyze-power.py nic-breakdown >> "$OUTPUT" 2>&1
echo "" >> "$OUTPUT"

echo "4. BY PROFILE" >> "$OUTPUT"
echo "=============" >> "$OUTPUT"
python3 bin/analyze-power.py by-profile >> "$OUTPUT" 2>&1
echo "" >> "$OUTPUT"

echo "5. COUNT BY TEST-TYPE" >> "$OUTPUT"
echo "=====================" >> "$OUTPUT"
python3 bin/analyze-power.py count --group-by test-type >> "$OUTPUT" 2>&1
echo "" >> "$OUTPUT"

echo "6. COUNT BY PROTOCOL" >> "$OUTPUT"
echo "====================" >> "$OUTPUT"
python3 bin/analyze-power.py count --group-by protocol >> "$OUTPUT" 2>&1
echo "" >> "$OUTPUT"

echo "7. COUNT BY TOPOLOGY" >> "$OUTPUT"
echo "====================" >> "$OUTPUT"
python3 bin/analyze-power.py count --group-by topology >> "$OUTPUT" 2>&1
echo "" >> "$OUTPUT"

echo "8. COUNT BY BENCHMARK" >> "$OUTPUT"
echo "=====================" >> "$OUTPUT"
python3 bin/analyze-power.py count --group-by benchmark >> "$OUTPUT" 2>&1
echo "" >> "$OUTPUT"

echo "9. COUNT BY PROFILE" >> "$OUTPUT"
echo "===================" >> "$OUTPUT"
python3 bin/analyze-power.py count --group-by profile >> "$OUTPUT" 2>&1
echo "" >> "$OUTPUT"

echo "10. HIGHEST BMC POWER (Top 10)" >> "$OUTPUT"
echo "===============================" >> "$OUTPUT"
python3 bin/analyze-power.py find-high --limit 10 --metric bmc >> "$OUTPUT" 2>&1
echo "" >> "$OUTPUT"

echo "11. LOWEST BMC POWER (Bottom 10)" >> "$OUTPUT"
echo "=================================" >> "$OUTPUT"
python3 bin/analyze-power.py find-low --limit 10 --metric bmc >> "$OUTPUT" 2>&1
echo "" >> "$OUTPUT"

echo "12. HIGHEST NIC POWER (Top 10)" >> "$OUTPUT"
echo "===============================" >> "$OUTPUT"
python3 bin/analyze-power.py find-high --limit 10 --metric nic >> "$OUTPUT" 2>&1
echo "" >> "$OUTPUT"

echo "13. LOWEST NIC POWER (Bottom 10)" >> "$OUTPUT"
echo "=================================" >> "$OUTPUT"
python3 bin/analyze-power.py find-low --limit 10 --metric nic >> "$OUTPUT" 2>&1
echo "" >> "$OUTPUT"

echo "Analysis complete! Output saved to: $OUTPUT"
