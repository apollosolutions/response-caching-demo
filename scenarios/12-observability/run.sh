#!/usr/bin/env bash
. "$(dirname "$0")/../../scripts/lib.sh"
require_stack
title "12 · Observability: metrics, Prometheus, Grafana"
reset_all

step "Generate a mix of hits and misses across subgraphs and connectors"
for i in 1 2 3 4 5; do
  gql ProductPage 'query ProductPage { products { id name inStock reviews { rating } brand { name } } }' >/dev/null
  gql Brands 'query Brands { brands { id name } }' >/dev/null
  gql Me 'query Me { me { name } }' '' -H "x-user-id: alice" >/dev/null
done
note "15 operations sent"

step "Router exposes apollo_router_response_cache_total (Prometheus format on :9080)"
metrics="$(curl -s http://localhost:9080/metrics)"
expect_contains "hit counter present" "$metrics" 'apollo_router_response_cache_total{cache_hit="true"'
expect_contains "connector sources reported as subgraph_name=\"catalog.rest\"" "$metrics" 'subgraph_name="catalog.rest"'
expect_contains "subgraph latency split by cache status" "$metrics" 'response_cache_status="hit"'

wait_for 6 "Prometheus scrapes every 5s"

step "Hit ratio per origin, from Prometheus"
resp="$(curl -s http://localhost:9090/api/v1/query --data-urlencode \
  'query=sum by (subgraph_name) (apollo_router_response_cache_total{cache_hit="true"}) / sum by (subgraph_name) (apollo_router_response_cache_total)')"
echo "$resp" | jq -r '.data.result[] | "    \(.metric.subgraph_name)\t\((.value[1] | tonumber * 100 | floor))% hits"' | column -t -s $'\t'
expect_eq "Prometheus returned per-origin hit ratios" "$(echo "$resp" | jq -r '.data.result | length > 0')" "true"

echo
note "Grafana dashboard:  http://localhost:3000  (Response Cache)"
note "Prometheus:         http://localhost:9090"
finish
