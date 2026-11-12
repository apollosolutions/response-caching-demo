# 08 · Cache debugger

**What it shows:** how to see exactly what the Router cached, for how long, why, and how to invalidate it.

```bash
./scenarios/08-cache-debugger/run.sh
```

## Enable it (dev only)

```yaml
response_cache:
  debug: true    # never in production: it exposes cache contents to callers
```

## In Apollo Sandbox

1. Open http://localhost:4000.
2. **Settings** (top left) → scroll down → enable **Cache debugger**.
3. Run a query, then in the response panel's dropdown pick **Cache debugger**.

Each row is one cache entry (a root field or an entity, from a subgraph or a connector source):

* **Created at** filled in → the entry is stored. Empty → it wasn't cacheable (private without an id, `no-store`, error...).
* **Source**: `subgraph` = fetched now, `cache` = served from Redis.
* Click a row for the `Cache-Control` the origin sent, the entity key, the subgraph query (including the generated operation name; see scenario 02), and the **invalidation tags**.
* **Invalidate** generates the `curl` for the invalidation endpoint.

## From the command line

Send `apollo-cache-debugging: true` and read `extensions.apolloCacheDebugging`:

```bash
curl -s http://localhost:4000/ -H 'content-type: application/json' \
  -H 'apollo-cache-debugging: true' \
  -d '{"query":"query ProductPage { products { id name inStock brand { name } } }"}' \
  | jq '.extensions.apolloCacheDebugging.data[] | {source, subgraphName, kind, cacheControl, invalidationKeys}'
```

Sample output from the script:

```
SOURCE    ORIGIN        KIND                     MAX-AGE  SCOPE   STORE  TAGS
subgraph  products      root:products            60       public  true   type-products-Query products
subgraph  inventory     entity:Product{"id":"1"} 10       public  true   type-inventory-Product stock-1
subgraph  catalog.rest  entity:Brand{"id":"b1"}  120      public  true   brand-b1
```

## Other debugging tools

* **`x-response-cache` headers** (Rhai, subgraphs only): `hit | partial_hit | miss` overall and per subgraph.
* **RedisInsight** (http://localhost:5540, database `redis:6379`): browse `demo:*` keys and their TTLs.
* **Traces**: `response_cache.lookup` / `response_cache.store` spans carry `cache.status`, `cache.key` and `ttl`.
