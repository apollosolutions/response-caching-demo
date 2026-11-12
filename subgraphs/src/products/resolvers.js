import { GraphQLError } from "graphql";
import { products } from "../data.js";

const ROUTER_INVALIDATION_URL = process.env.ROUTER_INVALIDATION_URL || "http://router:4005/invalidation";
const INVALIDATION_SHARED_KEY = process.env.INVALIDATION_SHARED_KEY;

// Mutation-driven invalidation: after a write, tell the Router which cache
// entries are now stale. This is the pattern we recommend in production —
// the service that owns the data owns its invalidation.
async function invalidate(requests) {
  if (!INVALIDATION_SHARED_KEY) {
    console.warn("[products] INVALIDATION_SHARED_KEY not set; skipping invalidation");
    return null;
  }
  const res = await fetch(ROUTER_INVALIDATION_URL, {
    method: "POST",
    headers: { authorization: INVALIDATION_SHARED_KEY, "content-type": "application/json" },
    body: JSON.stringify(requests),
  });
  const body = await res.text();
  console.log(`[products] invalidation ${res.status}: ${body}`);
  return body;
}

export const resolvers = {
  Query: {
    products: () => products,
    product: (_, { id }) => products.find((p) => p.id === id),
    productsByIds: (_, { ids }) => ids.map((id) => products.find((p) => p.id === id)).filter(Boolean),
    dealOfTheMinute: () => ({
      productId: String(1 + Math.floor(Math.random() * products.length)),
      discountPct: 5 + Math.floor(Math.random() * 30),
      generatedAt: new Date().toISOString(),
    }),
    brokenProduct: () => {
      throw new GraphQLError("Product service is having a bad day");
    },
  },
  Mutation: {
    updateProductPrice: async (_, { id, price }) => {
      const product = products.find((p) => p.id === id);
      if (!product) throw new GraphQLError(`No product ${id}`);
      product.price = price;
      await invalidate([
        { kind: "cache_tag", subgraphs: ["products"], cache_tag: `product-${id}` },
        { kind: "cache_tag", subgraphs: ["products"], cache_tag: "products" },
      ]);
      return product;
    },
  },
  Product: {
    __resolveReference: (ref) => products.find((p) => p.id === ref.id),
    brand: (p) => ({ id: p.brandId }),
  },
};
