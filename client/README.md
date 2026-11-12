# Client app: cache layers

A small React + Apollo Client 4 app (http://localhost:5173) that shows **which layer answered each request**:

| Badge | Meaning |
|---|---|
| **Apollo Client cache** | `InMemoryCache` answered; no network request was made |
| **Browser HTTP cache** | the browser replayed an earlier GET response (detected because its `x-served-at` header is older than the request) |
| **Router cache · hit / partial** | the Router answered from Redis, fully or partly |
| **Origin · miss** | the Router fetched everything from subgraphs |
| **Router (connector / not cached)** | connector-only or uncacheable response (Rhai's `x-response-cache` covers subgraphs only) |

## Things to try

1. **Products** twice with `cache-first`: the second is answered by Apollo Client and never leaves the tab.
2. Switch to `network-only` and run **Products**: Router cache hit, with `Cache-Control: max-age=…` counting down.
3. Switch transport to **GET** and run **Products** twice: the browser HTTP cache answers until `max-age` runs out. Then you get a Router hit again.
4. **ProductsWithStock** over GET: `max-age=10`, so the browser cache only helps for 10s.
5. **Me** as alice then bob with `network-only`: private, cached per user in the Router.
6. **Promotions** / **Deal**: `no-store`, so neither the browser nor Apollo Client's HTTP layer reuses them. (`cache-first` still serves them from `InMemoryCache`, which ignores HTTP headers.)

## Key settings (`src/apollo.js`)

```js
new HttpLink({
  uri: "http://localhost:4000/",
  useGETForQueries: true,                          // browser/CDN-cacheable
  headers: { "apollo-require-preflight": "true" }, // Router CSRF protection for GET
});
```

## Caveats

* **Apollo Client ignores `Cache-Control`.** `InMemoryCache` keeps data until you evict it or a policy refetches. Use `fetchPolicy` / `nextFetchPolicy` or polling to control freshness on the client.
* **Browser cache and private data:** the browser keys its HTTP cache by URL. If the user identity travels in a header (as `x-user-id` does here) and the Router doesn't send `Vary` for it, switching users in the same browser can replay the previous user's `private` response from the browser cache. Use cookies or an `Authorization` header (which browsers handle more conservatively), add `Vary`, or keep personalized queries on POST.
* The Router needs `cors.expose_headers` for the browser to read `cache-control`, `cache-tag` and `x-response-cache*`. See `router/router.yaml`.
