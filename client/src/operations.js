import { gql } from "@apollo/client";

export const OPERATIONS = [
  {
    name: "Products",
    hint: "root field, 60s",
    query: gql`
      query Products {
        products { id name price }
      }
    `,
  },
  {
    name: "ProductsWithStock",
    hint: "+ inventory 10s → lowest TTL wins",
    query: gql`
      query ProductsWithStock {
        products { id name price inStock quantity }
      }
    `,
  },
  {
    name: "ProductPage",
    hint: "+ reviews (fallback 45s) + brand connector",
    query: gql`
      query ProductPage {
        products { id name reviews { rating } brand { name } }
      }
    `,
  },
  {
    name: "Me",
    hint: "PRIVATE, per user",
    private: true,
    query: gql`
      query Me {
        me { id name email }
      }
    `,
  },
  {
    name: "Brands",
    hint: "connector, TTL from REST header",
    query: gql`
      query Brands {
        brands { id name country }
      }
    `,
  },
  {
    name: "Promotions",
    hint: "connector, no Cache-Control → no-store",
    query: gql`
      query Promotions {
        promotions { id title percentOff }
      }
    `,
  },
  {
    name: "Deal",
    hint: "maxAge 0 → never cached",
    query: gql`
      query Deal {
        dealOfTheMinute { productId discountPct generatedAt }
      }
    `,
  },
];
