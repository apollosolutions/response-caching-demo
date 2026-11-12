import { inventory } from "../data.js";

export const resolvers = {
  Product: {
    __resolveReference: (ref) => ({ id: ref.id, ...(inventory[ref.id] || { quantity: 0 }) }),
    inStock: (p) => p.quantity > 0,
  },
};
