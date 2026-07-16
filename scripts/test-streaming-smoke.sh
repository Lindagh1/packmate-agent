#!/usr/bin/env bash
# Smoke-test Packmate SSE streaming (Compose or any base URL).
# Usage: PACKMATE_API=http://127.0.0.1:8000 scripts/test-streaming-smoke.sh
set -euo pipefail

API="${PACKMATE_API:-http://127.0.0.1:8000}"
OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

echo "Streaming smoke against ${API}/api/v1/chat/stream"
START="$(date +%s.%N)"
curl -sS --max-time 180 -N \
  -H 'Content-Type: application/json' \
  -H 'Accept: text/event-stream' \
  -X POST "${API}/api/v1/chat/stream" \
  -d '{"message":"Je pars a Rome pendant quatre jours avec un bagage cabine."}' \
  >"$OUT" || true
END="$(date +%s.%N)"

python3 - <<PY
import json, re, statistics, time
from pathlib import Path
raw = Path("$OUT").read_text(errors="replace")
print("bytes", len(raw), "wall_s", round(float("$END")-float("$START"), 2))
assert "event: started" in raw, "missing started"
assert "think>" not in raw.lower()
assert "insulin" not in raw.lower()
assert "Traceback" not in raw
events = []
for block in raw.split("\n\n"):
    if not block.strip() or block.strip().startswith(":"):
        continue
    name="message"; data=None
    for line in block.splitlines():
        if line.startswith("event:"):
            name=line.split(":",1)[1].strip()
        elif line.startswith("data:"):
            try: data=json.loads(line.split(":",1)[1].strip())
            except Exception: data=line
    events.append((name, data))
names=[n for n,_ in events]
print("events", names[:12], "… total", len(names))
assert names and names[0]=="started"
assert "completed" in names or "error" in names
heartbeats=sum(1 for n,_ in events if n=="heartbeat")
print("heartbeats", heartbeats)
if "completed" in names:
    payload=next(d for n,d in events if n=="completed")
    assert payload.get("destination")
    assert payload.get("packing_items") is not None
    print("completed_destination", payload.get("destination"), "items", len(payload.get("packing_items") or []))
print("SMOKE_OK")
PY
