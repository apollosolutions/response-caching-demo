#!/usr/bin/env bash
. "$(dirname "$0")/../../scripts/lib.sh"
require_stack
title "10 · Apollo Connectors: caching REST responses"
reset_all

step "Root field connector: GET /brands returns Cache-Control: public, max-age=120"
gql Brands 'query Brands { brands { id name country } }'
expect_eq "client TTL comes from the REST API header" "$CC" "max-age=120,public"
gql Brands 'query Brands { brands { id name country } }'
expect_eq "REST API called once for two requests" "$(rest_stat 'GET /brands')" "1"
note "x-response-cache: $XCACHE (Rhai can't see connector sources; use the debugger or metrics)"

step "Entity connector: Product.brand → GET /brands/{id}, each Brand cached separately"
Q='query ProductBrands { products { id name brand { name country } } }'
gql ProductBrands "$Q"
expect_eq "5 products, 3 distinct brands → 3 REST calls" "$(rest_stat 'GET /brands/:id')" "3"
gql ProductBrands "$Q"
expect_eq "second request: no new REST calls" "$(rest_stat 'GET /brands/:id')" "3"
expect_eq "client TTL = min(products 60s, brands 120s)" "$CC" "max-age=60,public"

step "No Cache-Control at all (GET /promotions): cached anyway, but never advertised"
gql Promotions 'query Promotions { promotions { id title percentOff } }'
gql Promotions 'query Promotions { promotions { id title percentOff } }'
expect_eq "REST API called once: the Router cached it with the fallback ttl" "$(rest_stat 'GET /promotions')" "1"
expect_eq "client still gets no-store" "$CC" "no-store"
ttl="$(redis_ttl_for 'demo:*catalog.rest*Query*')"
note "Redis TTL of a catalog.rest root entry: ${ttl}s (fallback ttl 90s or header 120s)"

finish
