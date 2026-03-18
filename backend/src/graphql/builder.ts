import SchemaBuilder from "@pothos/core";
import type { AuthUser } from "../auth/middleware.js";

export interface GraphQLContext {
  authUser?: AuthUser;
}

export const builder = new SchemaBuilder<{ Context: GraphQLContext }>({});
