# 03 · Mixed TTLs

**What it shows:** one client response can combine data with very different freshness needs. The Router caches each part with its own TTL, refetches only what expired, and tells the client the lowest remaining TTL.

```bash
./scenarios/03-mixed-ttls/run.sh   # takes ~15s
```

## How it works

```graphql
# products subgraph
type Query { products: [Product!]! @cacheControl(maxAge: 60) }
type Product @key(fields: "id") @cacheControl(maxAge: 300) { ... }

# inventory subgraph: stock changes constantly
type Product @key(fields: "id") @cacheControl(maxAge: 10) {
  inStock: Boolean!
  quantity: Int!
}
```

| Time | products root (60s) | inventory entities (10s) | Client `Cache-Control` |
|---|---|---|---|
| t=0 | miss → stored | miss → stored | `max-age=10,public` |
| t=0+ | hit | hit | `max-age=10,public` |
| t=11s | **hit** | **miss** → refetched | `max-age=10,public` |

Without per-part caching you'd have to cache the whole page for 10s, or not at all.

### The rules

* **Inside one subgraph response**, Apollo Server uses the lowest hint of all the fields and types it resolved.
* **Across subgraphs**, the Router uses the lowest remaining TTL of every part it used for the client's `Cache-Control`. A response never claims to be fresher than its stalest part.

### Apollo Server tip

Put the hint on the **type** for entities you contribute to (`type Product @key(...) @cacheControl(maxAge: 10)`). `_entities` returns a union, and without a type-level hint the entity response gets the default `maxAge: 0` and is never cached.
