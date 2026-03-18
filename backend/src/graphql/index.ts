import { createYoga } from "graphql-yoga";
import { builder } from "./builder.js";
import "./types/index.js";

const schema = builder.toSchema();

export const yoga = createYoga({ schema });
