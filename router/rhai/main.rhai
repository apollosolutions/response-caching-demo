// =============================================================================
// main.rhai: response-caching helpers for the demo
// =============================================================================
//
// 1. private_id for PRIVATE data
//    The accounts subgraph returns `Cache-Control: private`. The Router only
//    caches private data when it can tell users apart, using the request
//    context key named by `private_id` in router.yaml ("user_id").
//    The demo reads the user from the `x-user-id` header to keep things simple.
//    In production, read the verified JWT `sub` claim instead:
//      request.context[Router.APOLLO_AUTHENTICATION_JWT_CLAIMS]["sub"]
//
// 2. Cache status response headers (for demos and debugging)
//      x-response-cache              hit | partial_hit | miss | none
//      x-response-cache-<subgraph>   per-subgraph status
//    Rolled up from the Router's per-subgraph cache info, recorded in the
//    subgraph_service response hook.
//
//    Limits:
//    * Rhai has no connector hook, so connector sources (catalog.*) are not
//      reflected here. Use the cache debugger or the
//      apollo.router.response.cache metric for connectors.
//    * `apollo::router::response_cache::cache_info_subgraph_<name>` is an
//      internal context key. Re-test this script after Router upgrades.
// =============================================================================

fn supergraph_service(service) {
    service.map_request(|request| {
        if "x-user-id" in request.headers {
            let user = request.headers["x-user-id"];
            if user != "" {
                request.context["user_id"] = user;
            }
        }
    });

    service.map_response(|response| {
        if !response.is_primary() {
            return;
        }
        // Lets the client app tell a fresh Router response from a copy
        // replayed by the browser's HTTP cache.
        response.headers["x-served-at"] = `${unix_ms_now()}`;

        let names = response.context["demo_cache_subgraphs"];
        if names == () || names.len() == 0 {
            response.headers["x-response-cache"] = "none";
            return;
        }

        let hits = 0;
        let misses = 0;
        for name in names {
            let status = response.context[`demo_cache_status_${name}`];
            response.headers[`x-response-cache-${name}`] = status;
            if status == "hit" {
                hits += 1;
            } else if status == "miss" {
                misses += 1;
            } else {
                hits += 1;
                misses += 1;
            }
        }
        response.headers["x-response-cache"] =
            if misses == 0 { "hit" } else if hits == 0 { "miss" } else { "partial_hit" };
    });
}

fn subgraph_service(service, subgraph) {
    service.map_response(|response| {
        let info = response.context[`apollo::router::response_cache::cache_info_subgraph_${subgraph}`];
        if info == () {
            return;
        }

        // info: #{ "<TypeName>": #{ hit: N, miss: N }, ... }
        let hit = 0;
        let miss = 0;
        for type_name in info.keys() {
            let counts = info[type_name];
            if counts.hit != () { hit += counts.hit; }
            if counts.miss != () { miss += counts.miss; }
        }
        let status = if miss == 0 && hit > 0 { "hit" } else if hit == 0 { "miss" } else { "partial_hit" };

        // A subgraph can be fetched more than once per operation: combine.
        let key = `demo_cache_status_${subgraph}`;
        let previous = response.context[key];
        if previous != () && previous != status {
            status = "partial_hit";
        }
        response.context[key] = status;

        let names = response.context["demo_cache_subgraphs"];
        if names == () { names = []; }
        if !names.contains(subgraph) {
            names.push(subgraph);
        }
        response.context["demo_cache_subgraphs"] = names;
    });
}
