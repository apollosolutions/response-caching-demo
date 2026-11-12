#!/usr/bin/env bash
. "$(dirname "$0")/../../scripts/lib.sh"
require_stack
title "06 · Private data: cached per user with private_id"
reset_all

Q='query Me { me { id name email } }'

step "Alice: first request is a miss"
gql Me "$Q" '' -H 'x-user-id: alice'
expect_eq "miss" "$XCACHE" "miss"
expect_contains "client Cache-Control is private" "$CC" "private"
expect_eq "returns Alice" "$(echo "$BODY" | jq -r '.data.me.name')" "Alice Rivera"

step "Alice again: served from Alice's part of the cache"
gql Me "$Q" '' -H 'x-user-id: alice'
expect_eq "hit" "$XCACHE" "hit"
expect_eq "accounts subgraph called once" "$(sg_stat accounts requests)" "1"

step "Bob: same query, different user → his own entry, never Alice's data"
gql Me "$Q" '' -H 'x-user-id: bob'
expect_eq "miss" "$XCACHE" "miss"
expect_eq "returns Bob" "$(echo "$BODY" | jq -r '.data.me.name')" "Bob Chen"
gql Me "$Q" '' -H 'x-user-id: bob'
expect_eq "Bob's second request is a hit" "$XCACHE" "hit"
expect_eq "returns Bob from cache" "$(echo "$BODY" | jq -r '.data.me.name')" "Bob Chen"

step "No user id: the Router knows this query returns private data, so it bypasses the cache"
gql Me "$Q"
gql Me "$Q"
expect_not_contains "anonymous requests never hit the cache (x-response-cache: $XCACHE)" "$XCACHE" "hit"
expect_eq "accounts called for alice, bob, and both anonymous requests" "$(sg_stat accounts requests)" "4"

finish
