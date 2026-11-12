# 05 · What is never cached

**What it shows:** the Router won't store data that is marked uncacheable, that failed, or that changes state.

```bash
./scenarios/05-not-cached/run.sh
```

| Case | Why it isn't cached | Client `Cache-Control` |
|---|---|---|
| `dealOfTheMinute` has `@cacheControl(maxAge: 0)` | Apollo Server sends `no-store` | `no-store` |
| `brokenProduct` throws | Responses with errors are never stored, so a transient failure isn't replayed | `no-store` |
| `updateProductPrice` mutation | Only queries are cached | n/a |
| Subgraph sends no `Cache-Control` at all | The Router doesn't guess freshness for subgraphs (connectors differ, see scenario 10) | `no-store` |
| `private` data with no `private_id` in the request | It can't be stored safely per user (scenario 06) | `private` |

## Apollo Server defaults to know

* Root fields and fields that return object types default to `maxAge: 0`. A query is only cacheable if **every** field it resolves allows it.
* Use `@cacheControl(inheritMaxAge: true)` on object fields that should inherit their parent's TTL. Without it, `Product.brand` would make every product query `no-store` (see `subgraphs/src/products/schema.graphql`).
* Return `Cache-Control: no-store` on error responses from non-Apollo servers.
