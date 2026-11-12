# 12 · Observability

**What it shows:** measuring cache effectiveness in production with Router metrics, a ready-made Grafana dashboard, and per-request headers.

```bash
./scenarios/12-observability/run.sh
open http://localhost:3000       # Grafana → "Response Cache" dashboard
```

## Router config

```yaml
telemetry:
  exporters:
    metrics:
      prometheus: { enabled: true, listen: 0.0.0.0:9080, path: /metrics }
  instrumentation:
    instruments:
      cache:
        apollo.router.response.cache:          # hit/miss counter
          attributes:
            graphql.type.name: true
            subgraph.name: { subgraph_name: true }
      subgraph:
        http.client.request.duration:          # subgraph latency by cache status
          attributes:
            subgraph.name: true
            response.cache.status: { response_cache_status: status }
```

## Key metrics

| Prometheus metric | Use it for |
|---|---|
| `apollo_router_response_cache_total{cache_hit, subgraph_name, graphql_type_name}` | hit ratio per subgraph / connector source / type. **Misses on a type with no hits are your best caching candidates.** |
| `http_client_request_duration_seconds{response_cache_status}` | latency saved: `hit` vs `miss` |
| `apollo_router_operations_response_cache_fetch_seconds` / `_insert_seconds` | Redis latency (tune `fetch_timeout`, `pool_size`) |
| `apollo_router_operations_response_cache_invalidation_*` | invalidation volume and duration |
| `apollo_router_cache_redis_errors_total` | Redis health |

Connector sources show up with `subgraph_name="catalog.rest"`. Custom attributes and selectors apply only to subgraph requests; connectors report a fixed attribute set.

## The Grafana dashboard

`observability/grafana/dashboards/response-cache.json` (provisioned automatically):

* overall hit ratio, plus hit ratio per subgraph and connector source
* hits and misses by origin and entity type
* subgraph p95 latency, hit vs miss
* Redis fetch/insert latency
* invalidation events and entries removed

## Per-request headers (Rhai)

`router/rhai/main.rhai` adds `x-response-cache: hit | partial_hit | miss | none` and `x-response-cache-<subgraph>`. They're handy for demos and debugging, but they rely on an internal context key and don't cover connectors. Use metrics for production dashboards.

## Traces

If you export traces, `response_cache.lookup` (attributes `kind`, `cache.status`, `cache.key`, `private`) and `response_cache.store` (`ttl`, `batch.size`) show cache time per subgraph fetch.
