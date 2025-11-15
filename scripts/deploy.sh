#!/bin/bash

set -e

echo "🚀 Starting deployment..."

# Проверка minikube
echo "🔍 Checking minikube status..."
if ! minikube status > /dev/null 2>&1; then
    echo "❌ Minikube is not running. Starting minikube..."
    minikube start
    minikube addons enable ingress
fi

# Пути к проектам
WEB_APP_DIR="../web"
CATALOG_APP_DIR="../catalog-service"
RECOMMENDER_APP_DIR="../recommender-service"
INFRA_DIR="."

# Проверяем существование web-app
if [ ! -d "$WEB_APP_DIR" ]; then
    echo "❌ Error: web-app directory not found at $WEB_APP_DIR"
    echo "💡 Make sure web-app is in the same directory as infra"
    exit 1
fi

# Проверяем .env для catalog-app
echo "🔍 Checking catalog-app environment..."
if [ -f "$CATALOG_APP_DIR/.env" ]; then
    echo "✅ .env file found for catalog-app"
else
    echo "⚠️  .env file not found for catalog-app, using defaults"
fi

# Сборка web-app
echo "📦 Building web-app from $WEB_APP_DIR..."
docker build -t web-app:latest $WEB_APP_DIR

# Сборка catalog-app через docker-compose
echo "📦 Building catalog-app with docker-compose..."
if [ -d "$CATALOG_APP_DIR" ]; then
    if [ -f "$CATALOG_APP_DIR/.env" ]; then
        cd "$CATALOG_APP_DIR" && docker-compose --env-file .env build catalog-service
    else
        cd "$CATALOG_APP_DIR" && docker-compose build catalog-service
    fi
    # Тегируем образ для Kubernetes
    docker tag $(cd "$CATALOG_APP_DIR" && docker-compose images -q catalog-service) catalog-app:latest 2>/dev/null || \
    echo "⚠️  Could not tag catalog-app image"
else
    echo "⚠️  catalog-app directory not found at $CATALOG_APP_DIR, skipping..."
fi

# Сборка recommender-app
echo "📦 Building recommender-app from $RECOMMENDER_APP_DIR..."
if [ -d "$RECOMMENDER_APP_DIR" ]; then
    docker build -t recommender-app:latest $RECOMMENDER_APP_DIR
else
    echo "⚠️  recommender-app directory not found at $RECOMMENDER_APP_DIR, skipping..."
fi

# Загрузка в minikube
echo "⬆️ Loading images to minikube..."
minikube image load web-app:latest

if docker images | grep -q "catalog-app"; then
    minikube image load catalog-app:latest
else
    echo "⚠️  catalog-app image not found, skipping..."
fi

if docker images | grep -q "recommender-app"; then
    minikube image load recommender-app:latest
else
    echo "⚠️  recommender-app image not found, skipping..."
fi

# Развертывание в Kubernetes
echo "🛠 Deploying to Kubernetes..."
kubectl apply -k $INFRA_DIR/k8s/overlays/production

echo "✅ Deployment completed!"
echo ""
echo "📊 Check status with: kubectl get pods -n web"
echo "🌐 Run in separate terminal: minikube tunnel"
echo "🎯 Web App: http://web.local"
echo "📚 Catalog App: http://catalog.local"
echo "🤖 Recommender App: http://recommender.local"
echo ""
echo "📝 To view logs:"
echo "   Web App: kubectl logs -f deployment/web-app -n web"
echo "   Catalog App: kubectl logs -f deployment/catalog-app -n web"
echo "   Recommender App: kubectl logs -f deployment/recommender-app -n web"