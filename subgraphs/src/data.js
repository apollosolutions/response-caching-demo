// In-memory data shared by the demo subgraphs.
export const products = [
  { id: "1", name: "Trail Backpack 30L", description: "Lightweight daypack", price: 129.0, brandId: "b1" },
  { id: "2", name: "Insulated Water Bottle", description: "Keeps drinks cold for 24h", price: 49.5, brandId: "b1" },
  { id: "3", name: "Standing Desk", description: "Electric height-adjustable desk", price: 349.0, brandId: "b2" },
  { id: "4", name: "Desk Lamp", description: "Warm LED lamp", price: 19.99, brandId: "b2" },
  { id: "5", name: "Studio Headphones", description: "Closed-back reference headphones", price: 899.0, brandId: "b3" },
];

export const inventory = {
  1: { quantity: 42 },
  2: { quantity: 0 },
  3: { quantity: 7 },
  4: { quantity: 120 },
  5: { quantity: 3 },
};

export const reviews = [
  { id: "r1", productId: "1", rating: 5, body: "Perfect size for day hikes." },
  { id: "r2", productId: "1", rating: 4, body: "Wish it had more pockets." },
  { id: "r3", productId: "3", rating: 5, body: "Quiet motor, sturdy frame." },
  { id: "r4", productId: "5", rating: 5, body: "Incredibly detailed sound." },
];

export const users = {
  alice: { id: "alice", name: "Alice Rivera", email: "alice@example.com", recentlyViewed: ["1", "3"] },
  bob: { id: "bob", name: "Bob Chen", email: "bob@example.com", recentlyViewed: ["5"] },
};
