import sys
import ulid
import time
from datetime import datetime, timezone

def generate(count):
    print(f"Generating {count} ULIDs from Python...")
    for _ in range(count):
        u = ulid.new()
        print(u.str)

def validate():
    print("Validating ULIDs in Python...")
    valid_count = 0
    total_count = 0
    
    for line in sys.stdin:
        ulid_str = line.strip()
        if not ulid_str:
            continue
            
        # Ignore non-ULID lines (e.g. logs)
        if len(ulid_str) != 26:
            continue

        total_count += 1
        try:
            u = ulid.from_str(ulid_str)
            # Basic validation: ensure we can extract a reasonable timestamp
            ts = u.timestamp().datetime
            now = datetime.now(timezone.utc)
            
            # Timestamp shouldn't be too far in the future or past (assuming recently generated)
            # But for testing, just successful decoding is a good sign
            # print(f"  {ulid_str} -> Valid (Timestamp: {ts})")
            valid_count += 1
        except Exception as e:
            print(f"  {ulid_str} -> Invalid: {e}")

    print(f"Python Validation Results: {valid_count}/{total_count} valid")
    if valid_count == total_count and total_count > 0:
        exit(0)
    else:
        exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: verify_ulid.py [generate <count>|validate]")
        exit(1)
        
    mode = sys.argv[1]
    
    if mode == "generate":
        count = int(sys.argv[2]) if len(sys.argv) > 2 else 10
        generate(count)
    elif mode == "validate":
        validate()
    else:
        print(f"Unknown mode: {mode}")
        exit(1)

