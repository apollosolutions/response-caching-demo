// Runs all four GraphQL subgraphs in one Node process, each at its own path:
//   http://subgraphs:4001/products | /inventory | /reviews | /accounts
//
// Every request the Router sends is counted, so scenarios can prove whether a
// response came from the Router's cache (counter unchanged) or the subgraph:
//   GET  /__stats  → { products: { requests, rootFetches, entityFetches, entityRepresentations }, ... }
//   POST /__reset  → zero all counters
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import express from "express";
import { ApolloServer } from "@apollo/server";
import { ApolloServerPluginCacheControl } from "@apollo/server/plugin/cacheControl";
import { expressMiddleware } from "@as-integrations/express5";
import { buildSubgraphSchema } from "@apollo/subgraph";
import { parse } from "graphql";

import { resolvers as productsResolvers } from "./products/resolvers.js";
import { resolvers as inventoryResolvers } from "./inventory/resolvers.js";
import { resolvers as reviewsResolvers } from "./reviews/resolvers.js";
import { resolvers as accountsResolvers } from "./accounts/resolvers.js";

const here = dirname(fileURLToPath(import.meta.url));
const PORT = process.env.PORT || 4001;

// The reviews subgraph simulates a server without @cacheControl support that
// still sends `Cache-Control: public` (no max-age). The Router falls back to
// the configured TTL for such responses.
const publicWithoutMaxAge = {
  async requestDidStart() {
    return {
      async willSendResponse({ response }) {
        const hasErrors = response.body.kind === "single" && response.body.singleResult.errors?.length;
        response.http.headers.set("cache-control", hasErrors ? "no-store" : "public");
      },
    };
  },
};

const subgraphs = [
  { name: "products", resolvers: productsResolvers },
  { name: "inventory", resolvers: inventoryResolvers },
  {
    name: "reviews",
    resolvers: reviewsResolvers,
    plugins: [ApolloServerPluginCacheControl({ calculateHttpHeaders: false }), publicWithoutMaxAge],
  },
  { name: "accounts", resolvers: accountsResolvers },
];

let stats = {};
const blank = () => ({ requests: 0, rootFetches: 0, entityFetches: 0, entityRepresentations: 0 });
const resetStats = () => {
  stats = Object.fromEntries(subgraphs.map((s) => [s.name, blank()]));
};
resetStats();

const app = express();
app.use(express.json({ limit: "1mb" }));

app.get("/__stats", (req, res) => res.json(stats));
app.post("/__reset", (req, res) => {
  resetStats();
  res.json({ ok: true });
});
app.get("/health", (req, res) => res.json({ ok: true }));

for (const sg of subgraphs) {
  const typeDefs = parse(readFileSync(join(here, sg.name, "schema.graphql"), "utf8"));
  const server = new ApolloServer({
    schema: buildSubgraphSchema([{ typeDefs, resolvers: sg.resolvers }]),
    plugins: sg.plugins ?? [],
  });
  await server.start();

  app.use(
    `/${sg.name}`,
    (req, res, next) => {
      if (req.method === "POST" && req.body?.query) {
        const s = stats[sg.name];
        s.requests++;
        const reps = req.body.variables?.representations;
        if (Array.isArray(reps)) {
          s.entityFetches++;
          s.entityRepresentations += reps.length;
        } else if (!req.body.query.includes("__ApolloGetServiceDefinition__")) {
          s.rootFetches++;
        }
      }
      next();
    },
    expressMiddleware(server, {
      context: async ({ req }) => ({ userId: req.headers["x-user-id"] }),
    })
  );
  console.log(`subgraph ${sg.name} → http://localhost:${PORT}/${sg.name}`);
}

app.listen(PORT, () => console.log(`Subgraphs listening on :${PORT}`));
