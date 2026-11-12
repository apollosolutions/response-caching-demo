#!/usr/bin/env bash
. "$(dirname "$0")/../../scripts/lib.sh"
require_stack
title "09 · Active invalidation (subgraphs)"
reset_all

KEY="${INVALIDATION_SHARED_KEY:?set INVALIDATION_SHARED_KEY in .env}"
PQ='query ProductById($id: ID!) { product(id: $id) { id name price } }'
LQ='query Products { products { id name price } }'
RQ='query ProductsWithReviews($ids: [ID!]!) { productsByIds(ids: $ids) { id reviews { rating } } }'

warm() {
  gql ProductById "$PQ" '{"id":"1"}' >/dev/null
  gql ProductById "$PQ" '{"id":"2"}' >/dev/null
  gql Products "$LQ" >/dev/null
  gql ProductsWithReviews "$RQ" '{"ids":["1","2"]}' >/dev/null
}

step "Warm the cache"
warm
gql ProductById "$PQ" '{"id":"1"}'
expect_eq "product 1 is cached" "$XCACHE" "hit"

step "By cache tag: product-1 (from @cacheTag(format: \"product-{\$args.id}\"))"
invalidate "$KEY" '[{"kind":"cache_tag","subgraphs":["products"],"cache_tag":"product-1"}]'
expect_eq "202 Accepted" "$INV_CODE" "202"
gql ProductById "$PQ" '{"id":"1"}'
expect_eq "product 1 → miss" "$XCACHE" "miss"
gql ProductById "$PQ" '{"id":"2"}'
expect_eq "product 2 untouched → hit" "$XCACHE" "hit"

step "By entity type: every Product entity from the reviews subgraph"
invalidate "$KEY" '[{"kind":"type","subgraph":"reviews","type":"Product"}]'
expect_eq "2 review entries removed" "$(echo "$INV_BODY" | jq -r .count)" "2"
gql ProductsWithReviews "$RQ" '{"ids":["1","2"]}'
expect_eq "reviews → miss" "$(hdr x-response-cache-reviews)" "miss"

step "By subgraph: everything the products subgraph has cached"
invalidate "$KEY" '[{"kind":"subgraph","subgraph":"products"}]'
gql Products "$LQ"
expect_eq "product list → miss" "$XCACHE" "miss"

step "Mutation-driven: the products service invalidates its own data after a write"
gql ProductById "$PQ" '{"id":"3"}' >/dev/null
gql ProductById "$PQ" '{"id":"3"}'
expect_eq "product 3 cached" "$XCACHE" "hit"
old_price="$(echo "$BODY" | jq -r .data.product.price)"
gql UpdatePrice 'mutation UpdatePrice { updateProductPrice(id: "3", price: 299) { price } }'
note "updateProductPrice → products service POSTs product-3 and products tags to /invalidation"
gql ProductById "$PQ" '{"id":"3"}'
expect_eq "product 3 → miss right after the mutation" "$XCACHE" "miss"
expect_eq "new price visible immediately" "$(echo "$BODY" | jq -r .data.product.price)" "299"
gql UpdatePrice "mutation UpdatePrice { updateProductPrice(id: \"3\", price: $old_price) { price } }" >/dev/null
note "price restored to $old_price"

step "Requests with the wrong shared key are rejected"
invalidate "not-the-key" '[{"kind":"subgraph","subgraph":"products"}]'
expect_eq "401 Unauthorized" "$INV_CODE" "401"

finish
