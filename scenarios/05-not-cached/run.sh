#!/usr/bin/env bash
. "$(dirname "$0")/../../scripts/lib.sh"
require_stack
title "05 · What is never cached: no-store, errors, mutations"
reset_all

step "maxAge: 0 → Apollo Server sends Cache-Control: no-store"
gql Deal 'query Deal { dealOfTheMinute { productId discountPct generatedAt } }'
first="$(echo "$BODY" | jq -r '.data.dealOfTheMinute.generatedAt')"
expect_eq "client receives no-store" "$CC" "no-store"
gql Deal 'query Deal { dealOfTheMinute { productId discountPct generatedAt } }'
second="$(echo "$BODY" | jq -r '.data.dealOfTheMinute.generatedAt')"
expect_eq "still a miss on the second request" "$XCACHE" "miss"
if [ "$first" != "$second" ]; then expect_eq "fresh data each time" "different" "different"; else expect_eq "fresh data each time" "same" "different"; fi
expect_eq "products subgraph called twice" "$(sg_stat products rootFetches)" "2"

step "Responses with GraphQL errors are never stored"
gql Broken 'query Broken { brokenProduct { id name } }'
expect_contains "response contains an error" "$BODY" '"errors"'
gql Broken 'query Broken { brokenProduct { id name } }'
expect_eq "second request is still a miss" "$XCACHE" "miss"
expect_eq "products subgraph called for both (2 + 2)" "$(sg_stat products rootFetches)" "4"
expect_eq "client receives no-store" "$CC" "no-store"

step "Mutations are never cached"
gql SetPrice 'mutation SetPrice { updateProductPrice(id: "4", price: 19.99) { id price } }'
gql SetPrice 'mutation SetPrice { updateProductPrice(id: "4", price: 19.99) { id price } }'
expect_eq "products subgraph executed both mutations (4 + 2)" "$(sg_stat products rootFetches)" "6"

finish
