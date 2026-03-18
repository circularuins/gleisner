import { builder } from "../builder.js";

builder.queryType({
  fields: (t) => ({
    hello: t.string({
      resolve: () => "Gleisner API is running",
    }),
  }),
});
