#!/usr/bin/env bash
. "$(dirname "$0")/../../scripts/lib.sh"
require_stack
title "03 · Mixed TTLs: each part expires on its own, the client gets the lowest"
reset_all

Q='query ProductsWithStock { products { id name price inStock quantity } }'

step "products (root, 60s) + inventory (entities, 10s)"
gql ProductsWithStock "$Q"
expect_eq "client Cache-Control uses the lowest TTL (inventory 10s)" "$CC" "max-age=10,public"
expect_eq "inventory resolved 5 entities" "$(sg_stat inventory entityRepresentations)" "5"

step "Immediately again: both parts come from cache"
gql ProductsWithStock "$Q"
expect_eq "full hit" "$XCACHE" "hit"

wait_for 11 "inventory's 10s TTL expires, products' 60s doesn't"

step "After 11s: products still cached, inventory refetched"
gql ProductsWithStock "$Q"
expect_eq "x-response-cache-products is hit" "$(hdr x-response-cache-products)" "hit"
expect_eq "x-response-cache-inventory is miss" "$(hdr x-response-cache-inventory)" "miss"
expect_eq "overall status is partial_hit" "$XCACHE" "partial_hit"
expect_eq "inventory called a second time (5 + 5)" "$(sg_stat inventory entityRepresentations)" "10"
expect_eq "products called only once" "$(sg_stat products rootFetches)" "1"

finish
