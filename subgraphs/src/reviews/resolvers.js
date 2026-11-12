import { reviews } from "../data.js";

export const resolvers = {
  Product: {
    __resolveReference: (ref) => ({ id: ref.id }),
    reviews: (p) => reviews.filter((r) => r.productId === p.id),
    averageRating: (p) => {
      const rs = reviews.filter((r) => r.productId === p.id);
      return rs.length ? rs.reduce((s, r) => s + r.rating, 0) / rs.length : null;
    },
  },
};
