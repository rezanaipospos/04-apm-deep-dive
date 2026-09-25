# syntax=docker/dockerfile:1
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json ./
RUN npm install
COPY . .
# Browser calls services via host-mapped ports through nginx proxy
ENV VITE_CINEMA_URL=
ENV VITE_LAYOUT_URL=
ENV VITE_CHECKOUT_URL=
ENV VITE_PAYMENT_URL=
RUN npm run build

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
