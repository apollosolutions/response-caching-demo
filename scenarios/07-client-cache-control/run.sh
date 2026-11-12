#!/usr/bin/env bash
. "$(dirname "$0")/../../scripts/lib.sh"
require_stack
title "07 · What the client sees: Cache-Control, Cache-Tag, GET requests"
reset_all

step "The Router computes the client Cache-Control from every part of the response"
gql Products 'query Products { products { id name } }'
expect_eq "products only → 60s public" "$CC" "max-age=60,public"
gql ProductsWithStock 'query ProductsWithStock { products { id name inStock } }'
expect_eq "with inventory → lowest TTL wins (10s)" "$CC" "max-age=10,public"
gql Me 'query Me { me { name } }' '' -H 'x-user-id: alice'
expect_contains "private data → private (no CDN/shared caching)" "$CC" "private"
gql Deal 'query Deal { dealOfTheMinute { discountPct } }'
expect_eq "uncacheable field → no-store" "$CC" "no-store"
gql Brands 'query Brands { brands { id name } }'
expect_eq "connector: TTL from the REST API header" "$CC" "max-age=120,public"
gql Promotions 'query Promotions { promotions { title } }'
expect_eq "connector without Cache-Control → no-store to the client" "$CC" "no-store"

step "max-age counts down: the Router reports remaining freshness, not the original TTL"
gql Products 'query Products { products { id name } }'
wait_for 3 "let the cached entry age"
gql Products 'query Products { products { id name } }'
age="$(echo "$CC" | sed -E 's/.*max-age=([0-9]+).*/\1/')"
if [ "$age" -le 57 ]; then expect_eq "max-age dropped to ${age}s" "ok" "ok"; else expect_eq "max-age dropped below 58" "$age" "<=57"; fi

step "Cache-Tag header (CDN invalidation): labels a CDN can purge by"
gql ProductById 'query ProductById { product(id: "1") { id name } }'
note "Cache-Tag: $CACHE_TAG"
expect_contains "contains the @cacheTag value" "$CACHE_TAG" "product-1"
expect_contains "contains the type label" "$CACHE_TAG" "type-products-Query"
expect_contains "contains the subgraph label" "$CACHE_TAG" "subgraph-products"

step "GET requests: cacheable by browsers and CDNs using the same Cache-Control"
code="$(curl -s -o /dev/null -w '%{http_code}' -G "$ROUTER_URL" --data-urlencode 'query={ products { id } }')"
expect_eq "GET without a preflight header is rejected (CSRF protection)" "$code" "400"
get_cc="$(curl -s -D - -o /dev/null -G "$ROUTER_URL" -H 'apollo-require-preflight: true' \
  --data-urlencode 'query=query Products { products { id name } }' | grep -i '^cache-control:' | cut -d' ' -f2- | tr -d '\r')"
expect_contains "GET with apollo-require-preflight gets a cacheable response" "$get_cc" "public"

finish
