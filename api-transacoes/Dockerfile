FROM node:16-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY app.js ./

EXPOSE 3000

USER node

CMD ["npm", "start"]

