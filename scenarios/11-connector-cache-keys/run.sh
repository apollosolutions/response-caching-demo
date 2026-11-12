#!/usr/bin/env bash
. "$(dirname "$0")/../../scripts/lib.sh"
require_stack
title "11 · Connectors: cache_key_headers and scoped invalidation"
reset_all

SG_KEY="${INVALIDATION_SHARED_KEY:?set INVALIDATION_SHARED_KEY in .env}"
CN_KEY="${CONNECTOR_INVALIDATION_SHARED_KEY:?set CONNECTOR_INVALIDATION_SHARED_KEY in .env}"
PQ='query PriceList { priceList { productId currency amount } }'
BQ='query Brands { brands { id name } }'

step "catalog.pricing has cache_key_headers: [x-currency]: one entry per currency"
gql PriceList "$PQ" '' -H 'x-currency: USD'
gql PriceList "$PQ" '' -H 'x-currency: USD'
expect_eq "USD fetched once" "$(rest_stat 'GET /prices [USD]')" "1"
gql PriceList "$PQ" '' -H 'x-currency: EUR'
expect_eq "EUR is a separate entry → fetched" "$(rest_stat 'GET /prices [EUR]')" "1"
expect_eq "EUR response is in EUR (never the cached USD one)" "$(echo "$BODY" | jq -r '.data.priceList[0].currency')" "EUR"
gql PriceList "$PQ" '' -H 'x-currency: EUR'
expect_eq "EUR second request → cached" "$(rest_stat 'GET /prices [EUR]')" "1"

step "catalog.rest has cache_key_headers: []: headers don't split the cache"
gql Brands "$BQ" '' -H 'x-currency: USD'
gql Brands "$BQ" '' -H 'x-currency: GBP'
expect_eq "one shared entry for every caller" "$(rest_stat 'GET /brands')" "1"

step "Connector entries have their own invalidation scope and shared key"
invalidate "$SG_KEY" '[{"kind":"connector","source":"catalog.rest"}]'
expect_eq "the subgraph key can't invalidate connector entries" "$INV_CODE" "401"

invalidate "$CN_KEY" '[{"kind":"cache_tag","sources":["catalog.rest"],"cache_tag":"brands"}]'
expect_eq "connector key + cache_tag with sources → 202" "$INV_CODE" "202"
gql Brands "$BQ"
expect_eq "brands refetched from the API" "$(rest_stat 'GET /brands')" "2"

invalidate "$CN_KEY" '[{"kind":"connector","source":"catalog.pricing"}]'
expect_eq "invalidate a whole source → 202" "$INV_CODE" "202"
expect_eq "both currency entries removed" "$(echo "$INV_BODY" | jq -r .count)" "2"
gql PriceList "$PQ" '' -H 'x-currency: USD'
expect_eq "USD refetched" "$(rest_stat 'GET /prices [USD]')" "2"

finish
