# 07 · Client-side cache settings

**What it shows:** what the Router tells clients, browsers and CDNs about cacheability, and how to use it.

```bash
./scenarios/07-client-cache-control/run.sh
```

## `Cache-Control` on the client response

The Router computes one header for the whole response from every part it used:

| Operation | Client `Cache-Control` | Why |
|---|---|---|
| `products { id name }` | `max-age=60,public` | root field TTL |
| `products { id name inStock }` | `max-age=10,public` | inventory's 10s is the lowest |
| `me { name }` | `max-age=60,private` | any private part makes the whole response private |
| `dealOfTheMinute` | `no-store` | any uncacheable part makes it all uncacheable |
| `brands` (connector) | `max-age=120,public` | REST API header |
| `promotions` (connector, no header) | `no-store` | the API never authorized downstream caching |

`max-age` is the **remaining** freshness. A response served from a 3-second-old entry reports `max-age=57`.

## `Cache-Tag`: CDN invalidation

```yaml
response_cache:
  cdn_invalidation:
    enabled: true          # header_name: "Surrogate-Key", header_delimiter: " " for Fastly
```

```
Cache-Tag: subgraph-products,type-products-Query,product-1
```

When the data changes, purge your CDN by the finest label (`product-1`). If you're not sure the purge reached every edge, escalate to `type-products-Query` or `subgraph-products`.

## Browser and CDN caching needs GET

`POST` responses aren't cached by browsers or most CDNs. Send queries as `GET` with the CSRF header the Router requires:

```bash
curl -G http://localhost:4000/ -H 'apollo-require-preflight: true' \
  --data-urlencode 'query=query Products { products { id name } }'
```

In Apollo Client:

```ts
new HttpLink({
  uri: "http://localhost:4000/",
  useGETForQueries: true,
  headers: { "apollo-require-preflight": "true" },
});
```

The **client app** (http://localhost:5173) shows this side by side with Apollo Client's own in-memory cache. See [`client/README.md`](../../client/README.md).

## Three layers, three jobs

| Layer | Scope | Controlled by |
|---|---|---|
| Apollo Client `InMemoryCache` | one browser tab | `fetchPolicy` (`cache-first`, `network-only`, ...) |
| Browser HTTP cache / CDN | one user / everyone at the edge | the Router's `Cache-Control` (GET only) + `Cache-Tag` purges |
| Router response cache | everyone, per entity | `@cacheControl` / REST headers + `/invalidation` |
