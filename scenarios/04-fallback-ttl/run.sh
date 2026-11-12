#!/usr/bin/env bash
. "$(dirname "$0")/../../scripts/lib.sh"
require_stack
title "04 · Fallback TTL: Cache-Control without max-age"
reset_all

Q='query ProductReviews { product(id: "1") { name reviews { rating body } } }'

step "reviews sends 'Cache-Control: public' with no max-age"
gql ProductReviews "$Q"
expect_eq "first request is a miss" "$XCACHE" "miss"
expect_eq "client TTL = min(products 60s, reviews fallback 45s)" "$CC" "max-age=45,public"

ttl="$(redis_ttl_for 'demo:*:subgraph:reviews:*')"
note "Redis TTL of the reviews entry: ${ttl}s"
if [ -n "$ttl" ] && [ "$ttl" -gt 40 ] && [ "$ttl" -le 45 ]; then
  expect_eq "reviews entry stored with the configured 45s ttl" "ok" "ok"
else
  expect_eq "reviews entry stored with the configured 45s ttl" "${ttl:-<no key>}" "40-45"
fi

step "Second request is served from cache"
gql ProductReviews "$Q"
expect_eq "hit" "$XCACHE" "hit"
expect_eq "reviews subgraph called once" "$(sg_stat reviews requests)" "1"

finish
