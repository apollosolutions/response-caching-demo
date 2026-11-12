# 02 · Entity caching

**What it shows:** entities fetched through `_entities` are cached **one representation at a time**, so a request that needs some cached and some new entities only sends the new ones to the subgraph (a partial hit).

```bash
./scenarios/02-entity-caching/run.sh
```

## How it works

`reviews` contributes `Product.reviews` and `Product.averageRating`. When a query needs them, the Router sends an `_entities` request with one representation per product:

```json
{ "representations": [{ "__typename": "Product", "id": "1" }, { "__typename": "Product", "id": "2" }] }
```

The Router caches each representation's result separately:

| Request | reviews subgraph receives | `x-response-cache-reviews` |
|---|---|---|
| `productsByIds(ids: ["1","2"])` | 2 representations | `miss` |
| `productsByIds(ids: ["1","2","3"])` | 1 representation (product 3) | `partial_hit` |
| same again | nothing | `hit` |

This is what makes entity caching more efficient than whole-response caching: a product's reviews are stored once and reused in every list or detail view that includes them.

## Gotcha: operation names are part of the entity key (Router v2.19)

The Router names subgraph operations after the client operation (`ProductDetail__reviews__1`), and the subgraph query text, name included, is part of the entity cache key. The cache debugger shows this under **subgraphRequest.operationName**.

| Client operation | Shares reviews entries with `ProductsWithReviews`? |
|---|---|
| `query ProductsWithReviews { product(id: "1") { reviews { rating } } }` | ✅ yes |
| `query ProductDetail { product(id: "1") { reviews { rating } } }` | ❌ no |

So entity reuse works across requests of the **same operation** (different variables, different lists) but not across differently named operations. Keep this in mind when you estimate hit rates. Persisted queries with stable names help.

## Try it in Sandbox

```graphql
query ProductsWithReviews($ids: [ID!]!) {
  productsByIds(ids: $ids) { id name reviews { rating } averageRating }
}
```

Run it with `{"ids": ["1","2"]}`, then `{"ids": ["1","2","3"]}`, and open the cache debugger. Products 1 and 2 show `source: cache`, and product 3 shows `source: subgraph`.
