#!/usr/bin/env bash
. "$(dirname "$0")/../../scripts/lib.sh"
require_stack
title "01 · Root field caching"
reset_all

step "First request: the products subgraph is called and the response is stored"
gql Products 'query Products { products { id name price } }'
expect_eq "first request is a miss" "$XCACHE" "miss"
expect_eq "products subgraph called once" "$(sg_stat products rootFetches)" "1"
expect_eq "TTL comes from @cacheControl(maxAge: 60)" "$CC" "max-age=60,public"

step "Same operation again: served from Redis, the subgraph is not called"
gql Products 'query Products { products { id name price } }'
expect_eq "second request is a hit" "$XCACHE" "hit"
expect_eq "products subgraph still called only once" "$(sg_stat products rootFetches)" "1"

step "Root fields with arguments: each argument value is its own cache entry"
Q='query ProductById($id: ID!) { product(id: $id) { id name price } }'
gql ProductById "$Q" '{"id":"1"}'
expect_eq "product(id: 1) → miss" "$XCACHE" "miss"
gql ProductById "$Q" '{"id":"1"}'
expect_eq "product(id: 1) again → hit" "$XCACHE" "hit"
gql ProductById "$Q" '{"id":"2"}'
expect_eq "product(id: 2) → miss (different variables, different entry)" "$XCACHE" "miss"
expect_eq "products subgraph root fetches: 1 + 2 misses" "$(sg_stat products rootFetches)" "3"

step "A different selection set is a different subgraph query, so a different entry"
gql ProductsNamesOnly 'query ProductsNamesOnly { products { id name } }'
expect_eq "products { id name } → miss" "$XCACHE" "miss"

finish
