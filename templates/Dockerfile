# 1. Start from the shared dev environment (Inherits system libs & Node)
# NOTE: DEV_BASE_IMAGE should be built upon PROD_BASE_IMAGE
FROM ${DEV_BASE_IMAGE} AS builder
WORKDIR /app
COPY . .
RUN npm install && npm run build

# 2. Extract to a lean production image
# We start fresh from the base to ensure zero bloat
FROM ${PROD_BASE_IMAGE} AS runner
WORKDIR /app
# Copy only production artifacts from dev-base
COPY --from=dev-base /app/node_modules ./node_modules
COPY --from=dev-base /app/.next ./.next
COPY --from=dev-base /app/public ./public
COPY --from=dev-base /app/package.json ./package.json

# Production runtime
CMD ["node", "node_modules/.bin/next", "start"]
