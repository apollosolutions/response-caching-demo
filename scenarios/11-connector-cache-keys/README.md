# 11 · Connector cache keys and invalidation

**What it shows:** how to keep connector caching **correct** when the REST API's response depends on request headers, and how to invalidate connector entries.

```bash
./scenarios/11-connector-cache-keys/run.sh
```

## `cache_key_headers`: a safety decision

A connector calls the REST API directly, so the Router can't know which request headers change the response. You have to tell it:

```yaml
response_cache:
  connector:
    all:
      cache_key_headers: []          # required: the Router won't start without it
    sources:
      catalog.pricing:
        cache_key_headers: [x-currency]   # replaces (doesn't merge with) the `all` list
```

```graphql
@source(name: "pricing",
  http: { baseURL: "http://rest-api:4010", headers: [{ name: "x-currency", from: "x-currency" }] })
```

| Request | `catalog.pricing` | `catalog.rest` |
|---|---|---|
| `x-currency: USD` | own entry | shared entry |
| `x-currency: EUR` | own entry (EUR prices) | same shared entry |

* **Leaving out a header the API varies on is a data leak.** User B gets user A's cached response. List every header you forward with `@connect`/`@source` `http.headers` that changes the response.
* **Listing a header that doesn't matter wastes cache.** A per-request ID gives every request its own entry and drives the hit rate toward zero.

## Invalidating connector entries

Connector and subgraph entries live in **separate scopes**, each authorized by its own shared key:

```yaml
connector:
  all:
    invalidation:
      enabled: true
      shared_key: ${env.CONNECTOR_INVALIDATION_SHARED_KEY}
```

| `kind` | Payload |
|---|---|
| `connector` | `{"kind":"connector","source":"catalog.pricing"}` |
| `type` | `{"kind":"type","source":"catalog.rest","type":"Brand"}` |
| `cache_tag` | `{"kind":"cache_tag","sources":["catalog.rest"],"cache_tag":"brand-b1"}` |

Note `source` / `sources` in place of `subgraph` / `subgraphs`. The same tag string in the subgraph and connector scopes refers to different entries, and the subgraph shared key gets `401` on connector entries.

Most third-party REST APIs don't return `apolloCacheTags` extensions, so rely on `@cacheTag` in the connector schema plus the `connector` and `type` kinds.
