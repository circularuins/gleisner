import { createYoga } from "graphql-yoga";
import { useDisableIntrospection } from "@graphql-yoga/plugin-disable-introspection";
import { builder } from "./builder.js";
import { env } from "../env.js";
import type { AuthUser } from "../auth/middleware.js";
import "./types/index.js";

const schema = builder.toSchema();

const isProduction = env.NODE_ENV === "production";

export const yoga = createYoga<{ authUser?: AuthUser }>({
  schema,
  graphiql: !isProduction,
  maskedErrors: isProduction,
  plugins: isProduction ? [useDisableIntrospection()] : [],
});
