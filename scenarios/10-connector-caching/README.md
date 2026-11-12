# 10 · Apollo Connectors caching

**What it shows:** REST APIs wired in with Apollo Connectors get the same Redis cache as subgraphs: root fields, entities and TTLs. The TTLs come from the REST API's own `Cache-Control` headers.

```bash
./scenarios/10-connector-caching/run.sh
```

## The connector subgraph

`connectors/catalog.graphql` defines a `catalog` subgraph with no server. The Router calls the REST mock (`rest-api/`) directly:

```graphql
extend schema
  @link(url: "https://specs.apollo.dev/connect/v0.4", import: ["@source", "@connect"])
  @source(name: "rest", http: { baseURL: "http://rest-api:4010" })

type Query {
  brands: [Brand!]!
    @connect(source: "rest", http: { GET: "/brands" }, selection: "id name country")
    @cacheTag(format: "brands")
}

type Brand @key(fields: "id") @cacheTag(format: "brand-{$key.id}")
  @connect(source: "rest", http: { GET: "/brands/{$this.id}" }, selection: "id name country") { ... }
```

## Config

Connector sources are named `<subgraph>.<source>` and configured under `connector`, mirroring `subgraph`:

```yaml
response_cache:
  connector:
    all:
      enabled: true
      ttl: 90s                 # fallback when the API sends no max-age
      cache_key_headers: []    # required (scenario 11)
      redis: { urls: ["redis://redis:6379"] }
    sources:
      catalog.pricing:
        cache_key_headers: [x-currency]
```

## What happens

| Endpoint | API's `Cache-Control` | Router cache | Client `Cache-Control` |
|---|---|---|---|
| `GET /brands` | `public, max-age=120` | 120s | `max-age=120,public` |
| `GET /brands/{id}` (entity) | `public, max-age=120` | 120s per brand | lowest across the response |
| `GET /promotions` | **none** | **90s (fallback `ttl`)** | `no-store` |

## How connectors differ from subgraphs

| | Subgraph | Connector |
|---|---|---|
| TTL source | `@cacheControl` → header | the REST API's `Cache-Control` header |
| No `Cache-Control` at all | not cached | cached for `ttl`, client gets `no-store` |
| Config block | `subgraph.all` / `subgraphs` | `connector.all` / `sources` |
| Cache key headers | n/a | `cache_key_headers` required |
| Invalidation | `subgraph`/`subgraphs` | `connector`/`source`/`sources`, separate shared key |
| Rhai on a cache hit | yes | no Rhai connector hook |
| A fully cached entity fetch | | makes no HTTP call at all, so no connector telemetry or coprocessor stages run |

The `x-response-cache` header in this demo comes from Rhai, so it only reflects subgraphs. For connectors, use the cache debugger (scenario 08) or the `apollo.router.response.cache` metric, where `subgraph.name` is the source name (scenario 12). The REST mock's `GET /__stats` counts real API calls.
