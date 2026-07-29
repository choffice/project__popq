FROM node:22-alpine AS build

WORKDIR /app
COPY web_react/seller-web/package.json web_react/seller-web/package-lock.json ./
RUN npm ci
COPY web_react/seller-web/ ./
RUN npm run build

FROM nginx:1.27-alpine
COPY deploy/nginx-spa.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
