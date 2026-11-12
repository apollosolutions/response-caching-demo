# 06 · Private data

**What it shows:** user-specific data can be cached safely. Each user gets their own cache entries, and a request without a user id never reads or writes them.

```bash
./scenarios/06-private-data/run.sh
```

## How it works

```graphql
# accounts subgraph
type Query {
  me: User @cacheControl(maxAge: 60, scope: PRIVATE)   # → Cache-Control: max-age=60, private
}
```

```yaml
# router.yaml
response_cache:
  subgraph:
    subgraphs:
      accounts:
        private_id: user_id   # request-context key that identifies the user
```

```rhai
// router/rhai/main.rhai: fills the context key
if "x-user-id" in request.headers {
    request.context["user_id"] = request.headers["x-user-id"];
}
```

| Request | Result |
|---|---|
| alice | miss → stored under Alice's private id |
| alice | **hit** |
| bob | miss, never sees Alice's entry |
| no user id | not cached: the Router has learned that `Me` returns private data |

The client response keeps `Cache-Control: private`, so browsers may cache it but shared caches and CDNs must not.

## Production: use the JWT, not a header

The demo trusts `x-user-id` to keep things simple. In production, use the Router's JWT authentication and the verified `sub` claim:

```yaml
authentication:
  router:
    jwt:
      jwks:
        - url: https://your-idp/.well-known/jwks.json
```

```rhai
fn supergraph_service(service) {
  service.map_request(|request| {
    let claims = request.context[Router.APOLLO_AUTHENTICATION_JWT_CLAIMS];
    if claims != () { request.context["user_id"] = claims["sub"]; }
  });
}
```

Connector sources take `private_id` too, under `response_cache.connector.sources.<subgraph.source>`.
