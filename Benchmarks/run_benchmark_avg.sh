#!/bin/bash

# Configuration
ITERATIONS=5
OUTPUT_FILE="benchmark_results.txt"
BENCHMARK_CMD="swift run -c release FastULIDBenchmark"

echo "🚀 Starting Average Performance Benchmark ($ITERATIONS runs)..."
echo "---------------------------------------------------"

# Clear previous results
rm -f "$OUTPUT_FILE"

# Run benchmark multiple times
for i in $(seq 1 $ITERATIONS); do
    echo "Running iteration $i/$ITERATIONS..."
    $BENCHMARK_CMD > "run_$i.log"
    
    # Extract key metrics using $(NF-1) which is robust against spaces in names
    gen_time=$(grep "ULIDGenerator.generate()" "run_$i.log" | head -1 | awk '{print $(NF-1)}')
    enc_time=$(grep "ULID.ulidString" "run_$i.log" | head -1 | awk '{print $(NF-1)}')
    dec_time=$(grep "ULID(ulidString:)" "run_$i.log" | head -1 | awk '{print $(NF-1)}')
    json_enc=$(grep "JSONEncoder.encode(ULID)" "run_$i.log" | head -1 | awk '{print $(NF-1)}')
    json_dec=$(grep "JSONDecoder.decode(ULID)" "run_$i.log" | head -1 | awk '{print $(NF-1)}')
    batch_time=$(grep "Batch Generation (per ULID)" "run_$i.log" | head -1 | awk '{print $(NF-1)}')
    
    # UUID metrics for comparison
    uuid_gen=$(grep "UUID() - Standard UUID" "run_$i.log" | head -1 | awk '{print $(NF-1)}')
    uuid_enc=$(grep "UUID.uuidString" "run_$i.log" | head -1 | awk '{print $(NF-1)}')
    uuid_dec=$(grep "UUID(uuidString:)" "run_$i.log" | head -1 | awk '{print $(NF-1)}')
    
    echo "$gen_time,$enc_time,$dec_time,$json_enc,$json_dec,$batch_time,$uuid_gen,$uuid_enc,$uuid_dec" >> "$OUTPUT_FILE"
done

echo "---------------------------------------------------"
echo "📊 Calculation Results (Average of $ITERATIONS runs):"
echo ""

# Calculate averages using awk
awk -F',' '{
    sum_gen+=$1; sum_enc+=$2; sum_dec+=$3; 
    sum_jenc+=$4; sum_jdec+=$5; sum_batch+=$6;
    sum_ugen+=$7; sum_uenc+=$8; sum_udec+=$9;
} END {
    printf "%-30s %10s ns\n", "Operation", "Average"
    printf "-------------------------------------------\n"
    printf "%-30s %10.2f ns\n", "ULID Generation", sum_gen/NR
    printf "%-30s %10.2f ns\n", "ULID String Encoding", sum_enc/NR
    printf "%-30s %10.2f ns\n", "ULID String Decoding", sum_dec/NR
    printf "%-30s %10.2f ns\n", "JSON Encoding", sum_jenc/NR
    printf "%-30s %10.2f ns\n", "JSON Decoding", sum_jdec/NR
    printf "%-30s %10.2f ns\n", "Batch Generation", sum_batch/NR
    printf "-------------------------------------------\n"
    printf "%-30s %10.2f ns\n", "UUID Generation", sum_ugen/NR
    printf "%-30s %10.2f ns\n", "UUID String Encoding", sum_uenc/NR
    printf "%-30s %10.2f ns\n", "UUID String Decoding", sum_udec/NR
}' "$OUTPUT_FILE"

# Clean up
rm run_*.log
rm "$OUTPUT_FILE"

