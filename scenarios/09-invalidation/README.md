# 09 · Active invalidation

**What it shows:** removing cached data the moment it changes, instead of waiting for the TTL, at three levels of precision.

```bash
./scenarios/09-invalidation/run.sh
```

## The endpoint

```yaml
response_cache:
  invalidation:
    listen: 0.0.0.0:4005          # internal network only in production
    path: /invalidation
  subgraph:
    all:
      invalidation:
        enabled: true
        shared_key: ${env.INVALIDATION_SHARED_KEY}
```

```bash
curl -X POST http://localhost:4005/invalidation \
  -H "authorization: $INVALIDATION_SHARED_KEY" -H 'content-type: application/json' \
  -d '[{"kind":"cache_tag","subgraphs":["products"],"cache_tag":"product-1"}]'
# → 202 {"count": 2}   (number of Redis entries removed)
```

## Three ways to target entries

| `kind` | Payload | Removes |
|---|---|---|
| `cache_tag` | `{"subgraphs":["products"],"cache_tag":"product-1"}` | entries tagged `product-1` (most precise) |
| `type` | `{"subgraph":"reviews","type":"Product"}` | every `Product` entity reviews contributed |
| `subgraph` | `{"subgraph":"products"}` | everything from that subgraph |

You can send several in one array.

## Where tags come from

```graphql
type Query {
  products: [Product!]! @cacheTag(format: "products")                  # static tag
  product(id: ID!): Product @cacheTag(format: "product-{$args.id}")     # from arguments
}
type Product @key(fields: "id") @cacheTag(format: "product-{$key.id}") # from the entity key
```

Subgraphs can also return tags they compute at runtime in `extensions.apolloCacheTags` (root fields) or `extensions.apolloEntityCacheTags` (entities).

## Mutation-driven invalidation (recommended pattern)

The service that owns the data invalidates it right after a successful write. See `subgraphs/src/products/resolvers.js`:

```js
updateProductPrice: async (_, { id, price }) => {
  product.price = price;
  await invalidate([
    { kind: "cache_tag", subgraphs: ["products"], cache_tag: `product-${id}` },
    { kind: "cache_tag", subgraphs: ["products"], cache_tag: "products" },
  ]);
  return product;
}
```

Combine TTLs and invalidation: use invalidation for freshness, and keep TTLs as a safety net in case an invalidation call is ever lost.

## Tuning

Each invalidation method maintains a Redis index on every write. If you only invalidate by tag, turn the others off under `invalidation.indexes` (`subgraph: false`, `type: false`).
