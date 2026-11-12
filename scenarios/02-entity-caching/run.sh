#!/usr/bin/env bash
. "$(dirname "$0")/../../scripts/lib.sh"
require_stack
title "02 · Entity caching (per-entity reuse and partial hits)"
reset_all

Q='query ProductsWithReviews($ids: [ID!]!) { productsByIds(ids: $ids) { id name reviews { rating } averageRating } }'

step "Fetch products 1 and 2: reviews resolves 2 Product entities and caches each one"
gql ProductsWithReviews "$Q" '{"ids":["1","2"]}'
expect_eq "reviews subgraph received 2 representations" "$(sg_stat reviews entityRepresentations)" "2"
expect_eq "x-response-cache-reviews is miss" "$(hdr x-response-cache-reviews)" "miss"

step "Fetch products 1, 2 and 3: only product 3 goes to the subgraph"
gql ProductsWithReviews "$Q" '{"ids":["1","2","3"]}'
expect_eq "reviews served a partial hit" "$(hdr x-response-cache-reviews)" "partial_hit"
expect_eq "reviews subgraph received only 1 new representation (2 + 1 = 3)" "$(sg_stat reviews entityRepresentations)" "3"

step "Same request again: every entity is cached"
gql ProductsWithReviews "$Q" '{"ids":["1","2","3"]}'
expect_eq "reviews is a full hit" "$(hdr x-response-cache-reviews)" "hit"
expect_eq "no new representations sent to reviews" "$(sg_stat reviews entityRepresentations)" "3"

step "Gotcha: the entity key includes the subgraph operation name"
note "The Router names subgraph operations <ClientOperation>__<subgraph>__<n>, and that"
note "query text is part of the entity cache key. An operation with a different name"
note "doesn't reuse the entries above (observed on Router v2.19)."
gql ProductDetail 'query ProductDetail { product(id: "1") { name reviews { rating } averageRating } }'
expect_eq "different operation name → reviews miss" "$(hdr x-response-cache-reviews)" "miss"
gql ProductsWithReviews 'query ProductsWithReviews { product(id: "1") { name reviews { rating } averageRating } }'
expect_eq "same operation name, different root query → reviews hit" "$(hdr x-response-cache-reviews)" "hit"

finish
