# Generated template
FROM ${DEV_BASE_IMAGE} AS dev-base
RUN npm install

FROM ${PROD_BASE_IMAGE} AS prod
WORKDIR /app
COPY --from=dev-base /app/node_modules ./node_modules
COPY --from=dev-base /app/.next ./.next
COPY --from=dev-base /app/public ./public
CMD ["node", "server.js"]
