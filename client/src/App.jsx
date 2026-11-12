import { useMemo, useState } from "react";
import { makeClient, network } from "./apollo.js";
import { OPERATIONS } from "./operations.js";

const POLICIES = [
  { value: "cache-first", label: "cache-first", note: "Apollo Client's cache, then network" },
  { value: "network-only", label: "network-only", note: "always network, then update the cache" },
  { value: "no-cache", label: "no-cache", note: "always network, never store" },
];

function layerFor(call, routerCache) {
  if (!call) return { label: "Apollo Client cache", tone: "client" };
  if (call.fromBrowserCache) return { label: "Browser HTTP cache", tone: "browser" };
  if (routerCache === "hit") return { label: "Router cache · hit", tone: "hit" };
  if (routerCache === "partial_hit") return { label: "Router cache · partial", tone: "partial" };
  if (routerCache === "miss") return { label: "Origin · miss", tone: "miss" };
  return { label: "Router (connector / not cached)", tone: "none" };
}

export default function App() {
  const [policy, setPolicy] = useState("cache-first");
  const [useGET, setUseGET] = useState(false);
  const [user, setUser] = useState("alice");
  const [log, setLog] = useState([]);
  const [selected, setSelected] = useState(null);
  const [clients, setClients] = useState(() => ({
    post: makeClient({ useGET: false }),
    get: makeClient({ useGET: true }),
  }));
  const client = useGET ? clients.get : clients.post;

  async function run(op) {
    const before = network.calls.length;
    const started = performance.now();
    let data;
    let error;
    try {
      const res = await client.query({
        query: op.query,
        fetchPolicy: policy,
        context: op.private && user ? { headers: { "x-user-id": user } } : {},
      });
      data = res.data;
      error = res.error;
    } catch (e) {
      error = e;
    }
    const call = network.calls.length > before ? network.calls[network.calls.length - 1] : null;
    const entry = {
      id: log.length + 1,
      at: new Date().toLocaleTimeString(),
      op: op.name + (op.private ? ` (${user || "anonymous"})` : ""),
      policy,
      transport: call ? call.method : "—",
      layer: layerFor(call, call?.routerCache),
      cacheControl: call?.cacheControl ?? "—",
      cacheTag: call?.cacheTag,
      ms: Math.round(performance.now() - started),
      data,
      error: error?.message,
    };
    setLog((l) => [entry, ...l]);
    setSelected(entry);
  }

  function resetClientCaches() {
    setClients({ post: makeClient({ useGET: false }), get: makeClient({ useGET: true }) });
  }

  const policyNote = useMemo(() => POLICIES.find((p) => p.value === policy)?.note, [policy]);

  return (
    <div className="page">
      <header>
        <h1>Cache layers</h1>
        <p className="lede">
          Run an operation and see which layer answered: Apollo Client's in-memory cache, the
          browser's HTTP cache, the Router's response cache, or the origin.
        </p>
      </header>

      <section className="controls">
        <label>
          <span>Apollo Client fetchPolicy</span>
          <select value={policy} onChange={(e) => setPolicy(e.target.value)}>
            {POLICIES.map((p) => (
              <option key={p.value} value={p.value}>{p.label}</option>
            ))}
          </select>
          <small>{policyNote}</small>
        </label>
        <label>
          <span>Transport</span>
          <select value={useGET ? "GET" : "POST"} onChange={(e) => setUseGET(e.target.value === "GET")}>
            <option value="POST">POST (browser never caches)</option>
            <option value="GET">GET (browser honors Cache-Control)</option>
          </select>
          <small>{useGET ? "useGETForQueries + apollo-require-preflight" : "default Apollo Client behavior"}</small>
        </label>
        <label>
          <span>User (x-user-id, for Me)</span>
          <select value={user} onChange={(e) => setUser(e.target.value)}>
            <option value="alice">alice</option>
            <option value="bob">bob</option>
            <option value="">anonymous</option>
          </select>
          <small>private data is cached per user</small>
        </label>
        <div className="actions">
          <button className="secondary" onClick={resetClientCaches}>Reset Apollo Client cache</button>
          <button className="secondary" onClick={() => { setLog([]); setSelected(null); }}>Clear log</button>
        </div>
      </section>

      <section className="ops">
        {OPERATIONS.map((op) => (
          <button key={op.name} onClick={() => run(op)}>
            <strong>{op.name}</strong>
            <span>{op.hint}</span>
          </button>
        ))}
      </section>

      <section className="results">
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>#</th><th>Operation</th><th>Policy</th><th>Via</th><th>Answered by</th>
                <th>Cache-Control</th><th>ms</th>
              </tr>
            </thead>
            <tbody>
              {log.length === 0 && (
                <tr><td colSpan="7" className="empty">Run an operation above.</td></tr>
              )}
              {log.map((e) => (
                <tr key={e.id} onClick={() => setSelected(e)} className={selected?.id === e.id ? "sel" : ""}>
                  <td>{e.id}</td>
                  <td>{e.op}</td>
                  <td>{e.policy}</td>
                  <td>{e.transport}</td>
                  <td><span className={`pill ${e.layer.tone}`}>{e.layer.label}</span></td>
                  <td><code>{e.cacheControl}</code></td>
                  <td>{e.ms}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <aside className="detail">
          {selected ? (
            <>
              <h2>#{selected.id} {selected.op}</h2>
              {selected.cacheTag && (<p><span className="k">Cache-Tag</span> <code>{selected.cacheTag}</code></p>)}
              {selected.error && <p className="err">{selected.error}</p>}
              <pre>{JSON.stringify(selected.data, null, 2)}</pre>
            </>
          ) : (
            <p className="empty">Select a row to see the response.</p>
          )}
        </aside>
      </section>

      <footer>
        <p>
          Try: run <b>Products</b> twice with <i>cache-first</i> (the second is answered by Apollo Client),
          switch to <i>network-only</i> (Router cache hit), then switch transport to <b>GET</b> and run it
          twice (the browser HTTP cache answers until max-age runs out).
        </p>
      </footer>
    </div>
  );
}
