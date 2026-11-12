// REST mock used by the `catalog` connector subgraph.
//
// Each endpoint returns a deliberately different Cache-Control header so the
// connector scenarios can show how the Router derives TTLs for connectors:
//
//   GET /brands          Cache-Control: public, max-age=120   → TTL from header
//   GET /brands/:id      Cache-Control: public, max-age=120   → entity fetch, TTL from header
//   GET /promotions      (no Cache-Control at all)            → cached for configured ttl, client gets no-store
//   GET /prices          Cache-Control: public, max-age=30    → varies on x-currency (cache_key_headers)
//
// Every call is counted so scenarios can prove whether the Router hit the API:
//   GET  /__stats   → { "GET /brands": 3, ... }
//   POST /__reset   → zero all counters
import express from "express";

const app = express();
app.disable("etag");
app.disable("x-powered-by");

const PORT = process.env.PORT || 4010;

const brands = [
  { id: "b1", name: "Northwind Outdoor", country: "US" },
  { id: "b2", name: "Contoso Home", country: "CA" },
  { id: "b3", name: "Fabrikam Audio", country: "DE" },
];

const promotions = [
  { id: "promo-1", title: "Spring sale", percentOff: 15 },
  { id: "promo-2", title: "Free shipping weekend", percentOff: 0 },
];

// Base prices in USD; converted per request using the x-currency header.
const basePrices = [
  { productId: "1", amount: 129.0 },
  { productId: "2", amount: 49.5 },
  { productId: "3", amount: 349.0 },
  { productId: "4", amount: 19.99 },
  { productId: "5", amount: 899.0 },
];
const fx = { USD: 1, EUR: 0.92, GBP: 0.79, CAD: 1.37 };

let stats = {};
const count = (key) => {
  stats[key] = (stats[key] || 0) + 1;
};

app.get("/brands", (req, res) => {
  count("GET /brands");
  res.set("Cache-Control", "public, max-age=120");
  res.json(brands);
});

app.get("/brands/:id", (req, res) => {
  count("GET /brands/:id");
  const brand = brands.find((b) => b.id === req.params.id);
  if (!brand) return res.status(404).set("Cache-Control", "no-store").json({ error: "not found" });
  res.set("Cache-Control", "public, max-age=120");
  res.json(brand);
});

app.get("/promotions", (req, res) => {
  count("GET /promotions");
  // Intentionally NO Cache-Control header.
  res.json(promotions);
});

app.get("/prices", (req, res) => {
  const currency = (req.get("x-currency") || "USD").toUpperCase();
  count(`GET /prices [${currency}]`);
  const rate = fx[currency] ?? 1;
  res.set("Cache-Control", "public, max-age=30");
  res.set("Vary", "x-currency");
  res.json(
    basePrices.map((p) => ({
      productId: p.productId,
      currency,
      amount: Math.round(p.amount * rate * 100) / 100,
    }))
  );
});

app.get("/__stats", (req, res) => res.json(stats));
app.post("/__reset", (req, res) => {
  stats = {};
  res.json({ ok: true });
});
app.get("/health", (req, res) => res.json({ ok: true }));

app.listen(PORT, () => console.log(`REST mock listening on :${PORT}`));
