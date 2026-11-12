#!/usr/bin/env bash
. "$(dirname "$0")/../../scripts/lib.sh"
require_stack
title "08 · Cache debugger"
reset_all

Q='query ProductPage { products { id name inStock brand { name } } }'

step "Without the debug header, nothing extra is returned"
gql ProductPage "$Q"
expect_eq "no apolloCacheDebugging extension" "$(echo "$BODY" | jq -r '.extensions.apolloCacheDebugging // "absent"')" "absent"
reset_all

step "With 'apollo-cache-debugging: true', the Router explains every cache entry"
gql ProductPage "$Q" '' -H 'apollo-cache-debugging: true'
entries="$(echo "$BODY" | jq -c '.extensions.apolloCacheDebugging.data // []')"
echo
echo "$entries" | jq -r '
  ["SOURCE","ORIGIN","KIND","MAX-AGE","SCOPE","STORE","TAGS"],
  (.[] | [
    .source,
    .subgraphName,
    (if .kind.rootFields then "root:" + (.kind.rootFields | join(",")) else "entity:" + .kind.typename + (.kind.entityKey | tostring) end),
    (.cacheControl.maxAge // "-" | tostring),
    (if .cacheControl.public then "public" elif .cacheControl.private then "private" else "-" end),
    (.shouldStore | tostring),
    (.invalidationKeys // [] | map(select(startswith("subgraph-") | not)) | join(" "))
  ]) | @tsv' | column -t -s $'\t' | sed 's/^/    /'
echo
expect_eq "entries reported for products, inventory and the catalog connector" \
  "$(echo "$entries" | jq -r '[.[].subgraphName] | unique | join(",")')" "catalog.rest,inventory,products"
expect_eq "nothing came from cache on the first request" \
  "$(echo "$entries" | jq -r '[.[] | select(.source == "cache")] | length')" "0"

step "Second request: entries now say source=cache"
gql ProductPage "$Q" '' -H 'apollo-cache-debugging: true'
expect_eq "every entry served from cache" \
  "$(echo "$BODY" | jq -r '[.extensions.apolloCacheDebugging.data[] | select(.source != "cache")] | length')" "0"
note "CDN header the Router emitted: $(echo "$BODY" | jq -r '.extensions.apolloCacheDebugging.cdnInvalidation.headerValue')"

finish
