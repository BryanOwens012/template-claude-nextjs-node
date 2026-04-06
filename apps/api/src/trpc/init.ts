import { initTRPC } from '@trpc/server';
import type { CreateExpressContextOptions } from '@trpc/server/adapters/express';

export const createContext = ({ req, res }: CreateExpressContextOptions) => ({ req, res });
type Context = Awaited<ReturnType<typeof createContext>>;

const t = initTRPC.context<Context>().create();

export const createRouter = t.router;
export const publicProcedure = t.procedure;
export const middleware = t.middleware;
