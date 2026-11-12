import { ApolloClient, HttpLink, InMemoryCache } from "@apollo/client";

const ROUTER_URL = import.meta.env.VITE_ROUTER_URL || "http://localhost:4000/";

// Every request that actually leaves Apollo Client goes through this fetch,
// so we can record the Router's caching headers. If a query resolves without
// calling it, Apollo Client answered from its own InMemoryCache.
export const network = { calls: [] };

async function recordingFetch(uri, options) {
  const startedAt = Date.now();
  const res = await fetch(uri, options);
  const h = (name) => res.headers.get(name);
  const servedAt = Number(h("x-served-at") || 0);
  network.calls.push({
    method: (options?.method || "POST").toUpperCase(),
    durationMs: Date.now() - startedAt,
    cacheControl: h("cache-control"),
    routerCache: h("x-response-cache"),
    cacheTag: h("cache-tag"),
    // A response replayed by the browser's HTTP cache carries the original,
    // older x-served-at timestamp.
    fromBrowserCache: servedAt > 0 && servedAt < startedAt - 50,
  });
  return res;
}

export function makeClient({ useGET }) {
  return new ApolloClient({
    cache: new InMemoryCache(),
    link: new HttpLink({
      uri: ROUTER_URL,
      fetch: recordingFetch,
      // GET makes responses cacheable by the browser HTTP cache and CDNs.
      // The Router requires a non-simple header on GET (CSRF protection).
      useGETForQueries: useGET,
      headers: useGET ? { "apollo-require-preflight": "true" } : {},
    }),
  });
}
