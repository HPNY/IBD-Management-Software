FROM node:22-alpine AS build
WORKDIR /app
RUN corepack enable
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml* tsconfig.base.json ./
COPY services/api/package.json services/api/
RUN pnpm install --filter @ibd/api --ignore-scripts
COPY services/api services/api
RUN pnpm --filter @ibd/api build

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/services/api/dist ./dist
COPY --from=build /app/services/api/package.json ./
COPY --from=build /app/node_modules ./node_modules
EXPOSE 3000
CMD ["node", "dist/main.js"]
