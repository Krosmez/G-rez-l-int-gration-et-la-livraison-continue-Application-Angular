# syntax=docker/dockerfile:1

###############################################################################
# Stage 1 : build de l'application Angular
###############################################################################
# Angular 20 (CLI) exige Node >= 20.19 ; on prend donc une 20.x récente.
FROM node:20.19-alpine AS build

WORKDIR /usr/src/app

# Installation des dépendances en s'appuyant sur le cache des couches Docker.
# On copie d'abord les manifests pour ne réinstaller que si elles changent.
COPY package.json package-lock.json ./
RUN npm ci --cache .npm --prefer-offline

# Copie du code source puis build de production.
COPY . .
RUN npm run build

###############################################################################
# Stage 2 : service de l'application via Nginx
###############################################################################
FROM nginx:1.27-alpine

# Configuration Nginx fournie par le projet (racine applicative : /app).
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Le builder Angular 20 (@angular/build:application) produit les fichiers
# statiques dans dist/olympic-games-starter/browser : c'est ce dossier
# (et non son parent) qui doit être servi depuis /app.
COPY --from=build /usr/src/app/dist/olympic-games-starter/browser/ /app/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
