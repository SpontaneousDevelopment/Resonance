#!/usr/bin/env bash
# End-to-end proof that "delete my data" deletes everything.
#
# Runs against the local stack, using a genuine magic-link session rather than
# a hand-minted token: the link is pulled out of Mailpit, which captures every
# auth email the local stack sends. That means this exercises the real sign-in
# path a user walks — GoTrue issues the link, the link is redeemed for a real
# session, and the delete runs as that session — not a shortcut around it.
#
# Production auth config is deliberately untouched. Anonymous sign-in stays
# off: sign-in is the one deliberate gate before anything reaches the server.
set -euo pipefail

# The CLI derives its container names from the project directory, so this has
# to run from `backend/` no matter where it was invoked from.
cd "$(dirname "$0")/../.."

API=http://127.0.0.1:54321
MAILPIT=http://127.0.0.1:54324
EMAIL="delete-probe-$(date +%s)@local.dev"

ANON=$(supabase status -o json 2>/dev/null | sed -n 's/.*"ANON_KEY": *"\([^"]*\)".*/\1/p')
SERVICE=$(supabase status -o json 2>/dev/null | sed -n 's/.*"SERVICE_ROLE_KEY": *"\([^"]*\)".*/\1/p')
[ -n "$ANON" ] && [ -n "$SERVICE" ] || { echo "FAIL: local stack not running"; exit 1; }

pass=0; fail=0
check() { # check <label> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "  ok   $1"; pass=$((pass+1))
  else echo "  FAIL $1 — expected [$2], got [$3]"; fail=$((fail+1)); fi
}

echo "1. request a magic link for $EMAIL"
curl -s -X POST "$API/auth/v1/otp" -H "apikey: $ANON" -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"create_user\":true}" >/dev/null

echo "2. pull it out of Mailpit"
TOKEN=""
for _ in $(seq 1 30); do
  # Match on the recipient rather than a full-text search: the address is
  # unique per run, so this cannot pick up a link from an earlier one.
  TOKEN=$(curl -s "$MAILPIT/api/v1/messages?limit=50" | python3 -c '
import json, sys, urllib.request, urllib.parse, re
inbox, want = json.load(sys.stdin), sys.argv[1]
for m in inbox["messages"]:
    if any(t["Address"] == want for t in m["To"]):
        body = json.load(urllib.request.urlopen(
            "http://127.0.0.1:54324/api/v1/message/" + m["ID"]))
        hit = re.search(r"[?&]token=([A-Za-z0-9_-]+)", body.get("Text") or "")
        if hit:
            print(hit.group(1)); break
' "$EMAIL")
  [ -n "$TOKEN" ] && break
  sleep 1
done
[ -n "$TOKEN" ] || { echo "FAIL: no magic link arrived in Mailpit"; exit 1; }
echo "   got a token from the delivered email"

echo "3. redeem it for a real session"
SESSION=$(curl -s -X POST "$API/auth/v1/verify" -H "apikey: $ANON" -H "Content-Type: application/json" \
  -d "{\"type\":\"magiclink\",\"token_hash\":\"$TOKEN\"}")
JWT=$(printf '%s' "$SESSION" | sed -n 's/.*"access_token": *"\([^"]*\)".*/\1/p')
UID_=$(printf '%s' "$SESSION" | sed -n 's/.*"id": *"\([^"]*\)".*/\1/p' | head -1)
[ -n "$JWT" ] || { echo "FAIL: could not redeem the link: $SESSION"; exit 1; }
echo "   signed in as $UID_"

echo "4. write data as that user, the way the app does"
AUTH=(-H "apikey: $ANON" -H "Authorization: Bearer $JWT" -H "Content-Type: application/json")
ATTEMPT=$(uuidgen | tr 'A-Z' 'a-z')
curl -s -o /dev/null -w "" -X POST "$API/rest/v1/attempts" "${AUTH[@]}" \
  -d "{\"id\":\"$ATTEMPT\",\"user_id\":\"$UID_\",\"lesson_id\":\"plosive-1\",\"recorded_at\":\"2026-08-31T10:00:00Z\",\"duration_ms\":4200,\"score\":81}"
curl -s -o /dev/null -X POST "$API/rest/v1/lesson_progress" "${AUTH[@]}" \
  -d "{\"user_id\":\"$UID_\",\"lesson_id\":\"plosive-1\",\"unit_id\":\"articulation\",\"mastery_rank\":2}"
curl -s -o /dev/null -X POST "$API/rest/v1/streak_state" "${AUTH[@]}" \
  -d "{\"user_id\":\"$UID_\",\"current_streak\":3,\"longest_streak\":5}"

n_before=$(curl -s "$API/rest/v1/attempts?select=id&user_id=eq.$UID_" "${AUTH[@]}" | grep -c '"id"' || true)
check "the attempt is on the server before deleting" "1" "$n_before"

echo "5. invoke delete-account with that session"
STATUS=$(curl -s -o /tmp/del_body.txt -w '%{http_code}' -X POST "$API/functions/v1/delete-account" \
  -H "apikey: $ANON" -H "Authorization: Bearer $JWT")
check "the function reports success" "200" "$STATUS"

echo "6. confirm it is actually gone — asked as the service role, which RLS cannot hide from"
SVC=(-H "apikey: $SERVICE" -H "Authorization: Bearer $SERVICE")
for t in attempts lesson_progress streak_state profiles; do
  left=$(curl -s "$API/rest/v1/$t?select=user_id&user_id=eq.$UID_" "${SVC[@]}" | grep -c '"user_id"' || true)
  check "no rows left in $t" "0" "$left"
done

gone=$(curl -s -o /dev/null -w '%{http_code}' "$API/auth/v1/admin/users/$UID_" "${SVC[@]}")
check "the auth account itself is gone" "404" "$gone"

# The session token outlives the account it belonged to: a JWT is stateless, so
# PostgREST keeps honouring the signature until it expires. That is only safe
# because there is nothing left for it to reach and nothing it can create — both
# asserted here rather than assumed, since "the account is gone" and "the token
# is harmless" are different claims.
STALE_READ=$(curl -s "$API/rest/v1/attempts?select=id" -H "apikey: $ANON" -H "Authorization: Bearer $JWT")
check "a stale token reads no data" "[]" "$STALE_READ"

NEW_ID=$(uuidgen | tr 'A-Z' 'a-z')
PAYLOAD=$(printf '{"id":"%s","user_id":"%s","lesson_id":"x","recorded_at":"2026-08-31T10:00:00Z","duration_ms":1,"score":1}' "$NEW_ID" "$UID_")
STALE_WRITE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/rest/v1/attempts" \
  -H "apikey: $ANON" -H "Authorization: Bearer $JWT" -H 'Content-Type: application/json' -d "$PAYLOAD")
check "a stale token cannot write new data" "409" "$STALE_WRITE"

echo
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
