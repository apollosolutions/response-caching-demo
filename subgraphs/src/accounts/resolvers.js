import { users } from "../data.js";

export const resolvers = {
  Query: {
    me: (_, __, { userId }) => (userId ? users[userId] ?? null : null),
  },
  User: {
    __resolveReference: (ref) => users[ref.id],
    recentlyViewed: (u) => u.recentlyViewed.map((id) => ({ id })),
  },
};
