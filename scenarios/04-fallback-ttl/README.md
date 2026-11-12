# 04 · Fallback TTL

**What it shows:** where the TTL comes from when the origin doesn't specify one.

```bash
./scenarios/04-fallback-ttl/run.sh
```

## The TTL decision table

| Origin response | Subgraph | Connector source |
|---|---|---|
| `Cache-Control: max-age=N` | cached for **N** | cached for **N** |
| `Cache-Control: public` (no max-age) | cached for the **configured `ttl`** | cached for the **configured `ttl`** |
| No `Cache-Control` header at all | **not cached** | cached for the **configured `ttl`**, client gets `no-store` (scenario 10) |
| `no-store`, `max-age=0`, or errors | not cached | not cached |

## In this demo

The `reviews` subgraph simulates a GraphQL server without `@cacheControl` support that sends `Cache-Control: public` with no max-age. The Router falls back to the per-subgraph `ttl`:

```yaml
response_cache:
  subgraph:
    all:
      ttl: 120s          # default fallback for every subgraph
    subgraphs:
      reviews:
        ttl: 45s         # per-subgraph override
```

The script checks the real TTL on the Redis key (`redis-cli TTL`). You can also browse the keys in RedisInsight at http://localhost:5540 (add database `redis:6379`).

## Recommendation

Set `ttl` to a safe upper bound (the docs suggest no more than 24h, or twice your median schema publish interval) and let subgraphs send explicit `max-age` values. The fallback is a safety net, not the main control.
