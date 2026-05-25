FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY src/ ./src/
COPY migrations/ ./migrations/
COPY database/ ./database/
COPY scripts/ ./scripts/

EXPOSE 3001

CMD ["node", "src/server.js"]
