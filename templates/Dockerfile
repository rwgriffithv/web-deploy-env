ARG IMAGE_REGISTRY=local
ARG DEV_BASE_IMAGE=${IMAGE_REGISTRY}/web-deploy-base:latest
ARG PROD_BASE_IMAGE=${IMAGE_REGISTRY}/web-deploy-base:latest

FROM ${DEV_BASE_IMAGE} AS dev-base
WORKDIR /app
COPY . .
USER root
RUN npm install && npm run build

FROM ${PROD_BASE_IMAGE} AS prod
WORKDIR /app
COPY --from=dev-base /app/.next/standalone ./
COPY --from=dev-base /app/.next/static ./.next/static
COPY --from=dev-base /app/public ./public

CMD ["node", "server.js"]
