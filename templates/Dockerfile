ARG IMAGE_REGISTRY=local
ARG DEV_BASE_IMAGE=${IMAGE_REGISTRY}/agent-dev-env:latest
ARG PROD_BASE_IMAGE=${IMAGE_REGISTRY}/web-deploy-base:latest

FROM ${DEV_BASE_IMAGE} AS dev-base
WORKDIR /app
COPY . .
USER root
RUN npm install && npm run build

FROM ${PROD_BASE_IMAGE} AS prod
WORKDIR /app
COPY --from=dev-base /app/node_modules ./node_modules
COPY --from=dev-base /app/.next ./.next
COPY --from=dev-base /app/public ./public
COPY --from=dev-base /app/package.json ./package.json

CMD ["node", "node_modules/.bin/next", "start"]
