# 01 · Root field caching

**What it shows:** the Router caches the response of a root query field (`Query.products`, `Query.product(id:)`) as one unit, and serves repeats from Redis without calling the subgraph.

```bash
./scenarios/01-root-field-caching/run.sh
```

## How it works

```graphql
# subgraphs/src/products/schema.graphql
type Query {
  products: [Product!]! @cacheControl(maxAge: 60) @cacheTag(format: "products")
  product(id: ID!): Product @cacheControl(maxAge: 60) @cacheTag(format: "product-{$args.id}")
}
```

1. Apollo Server turns `@cacheControl(maxAge: 60)` into `Cache-Control: max-age=60, public` on the subgraph response.
2. The Router stores that subgraph response in Redis for 60s.
3. The next identical subgraph query is answered from Redis.

The cache key is built from the **exact subgraph query plus its variables**, so:

| Request | Result |
|---|---|
| `product(id: "1")` then `product(id: "1")` | miss → hit |
| `product(id: "2")` | miss (new variables) |
| `products { id name }` after `products { id name price }` | miss (different selection) |

When several root fields from one subgraph are in the same operation, they're cached together as a single entry.

## Try it in Sandbox

Open http://localhost:4000, run the query twice and watch the `x-response-cache` response header change from `miss` to `hit`.

```graphql
query Products {
  products { id name price }
}
```

## Config

```yaml
# router/router.yaml
response_cache:
  enabled: true
  subgraph:
    all:
      enabled: true
      ttl: 120s           # only used when Cache-Control has no max-age
      redis:
        urls: ["redis://redis:6379"]
```
