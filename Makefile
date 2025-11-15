# Пути
WEB_APP_DIR ?= ../web
CATALOG_APP_DIR ?= ../catalog-service
RECOMMENDER_APP_DIR ?= ../recommender-service
INFRA_DIR ?= .

.PHONY: check-minikube build-web-app build-catalog-app build-recommender-app load-web-app load-catalog-app load-recommender-app deploy-all up down status

# Проверка что minikube запущен
check-minikube:
	@echo "🔍 Checking minikube status..."
	@minikube status > /dev/null 2>&1 || (echo "❌ Minikube is not running. Run 'minikube start' first." && exit 1)
	@echo "✅ Minikube is running"

# Сборка web-app
build-web-app:
	@echo "📦 Building web-app..."
	docker build -t web-app:latest $(WEB_APP_DIR)

# Сборка catalog-app через docker compose
build-catalog-app:
	@echo "📦 Building catalog-app with docker compose..."
	@if [ -d "$(CATALOG_APP_DIR)" ]; then \
		echo "Checking for .env file..."; \
		if [ -f "$(CATALOG_APP_DIR)/.env" ]; then \
			echo "✅ .env file found, using it for build"; \
		else \
			echo "⚠️  .env file not found, using default values"; \
		fi; \
		echo "Building catalog-app and its dependencies..."; \
		cd $(CATALOG_APP_DIR) && docker compose --env-file .env build catalog-service; \
		echo "Tagging catalog-app image..."; \
		docker tag $$(cd $(CATALOG_APP_DIR) && docker compose images -q catalog-service) catalog-app:latest 2>/dev/null || \
		docker tag $$(docker images --filter=reference='*catalog-service*' --format "{{.ID}}" | head -1) catalog-app:latest 2>/dev/null || \
		echo "⚠️  Could not tag catalog-app image, trying alternative..."; \
		# Альтернативный способ получения image ID \
		if docker images | grep -q "catalog-service"; then \
			docker tag $$(docker images --filter=reference='*catalog-service*' --format "{{.ID}}" | head -1) catalog-app:latest && \
			echo "✅ catalog-app image tagged successfully"; \
		else \
			echo "❌ Failed to tag catalog-app image"; \
		fi; \
	else \
		echo "⚠️  catalog-app directory not found at $(CATALOG_APP_DIR), skipping..."; \
	fi

# Сборка recommender-app
build-recommender-app:
	@echo "📦 Building recommender-app..."
	@if [ -d "$(RECOMMENDER_APP_DIR)" ]; then \
		docker build -t recommender-app:latest $(RECOMMENDER_APP_DIR); \
	else \
		echo "⚠️  recommender-app directory not found at $(RECOMMENDER_APP_DIR), skipping..."; \
	fi

# Загрузка web-app в minikube
load-web-app:
	@echo "⬆️ Loading web-app to minikube..."
	minikube image load web-app:latest

# Загрузка catalog-app в minikube
load-catalog-app:
	@echo "⬆️ Loading catalog-app to minikube..."
	@if docker images | grep -q "catalog-app"; then \
		minikube image load catalog-app:latest; \
	else \
		echo "⚠️  catalog-app image not found, skipping..."; \
	fi

# Загрузка recommender-app в minikube
load-recommender-app:
	@echo "⬆️ Loading recommender-app to minikube..."
	@if docker images | grep -q "recommender-app"; then \
		minikube image load recommender-app:latest; \
	else \
		echo "⚠️  recommender-app image not found, skipping..."; \
	fi

# Деплой всей инфраструктуры
deploy-all: check-minikube build-web-app build-catalog-app build-recommender-app load-web-app load-catalog-app load-recommender-app
	@echo "🛠 Deploying to Kubernetes..."
	kubectl apply -k $(INFRA_DIR)/k8s/overlays/production
	@echo "✅ All services deployed"

# Запуск всей инфраструктуры
up: deploy-all
	@echo "🏁 Infrastructure is running!"
	@echo "💡 Run in separate terminal: minikube tunnel"
	@echo "🌐 Web App: http://web.local"
	@echo "📚 Catalog App: http://catalog.local"
	@echo "🎯 Recommender App: http://recommender.local"

# Остановка
down:
	@echo "🛑 Stopping infrastructure..."
	kubectl delete -k $(INFRA_DIR)/k8s/overlays/production

# Статус
status: check-minikube
	@echo "=== Namespaces ==="
	kubectl get namespaces | grep -E "(web|NAME)"
	@echo "=== Pods in web ==="
	kubectl get pods -n web
	@echo "=== Services in web ==="
	kubectl get services -n web
	@echo "=== Ingress in web ==="
	kubectl get ingress -n web

# Очистка образов
clean:
	@echo "🧹 Cleaning up images..."
	docker rmi web-app:latest || true
	docker rmi catalog-app:latest || true
	docker rmi recommender-app:latest || true

# Очистка docker-compose
clean-compose:
	@echo "🧹 Cleaning up docker-compose services..."
	@if [ -d "$(CATALOG_APP_DIR)" ]; then \
		cd $(CATALOG_APP_DIR) && docker-compose down -v --remove-orphans || true; \
	fi

# Полная очистка
clean-all: clean clean-compose
	@echo "✅ Full cleanup completed"

# Перезапуск
restart: down up

# Инициализация minikube
init-minikube:
	@echo "🚀 Initializing minikube..."
	minikube start
	minikube addons enable ingress
	@echo "✅ Minikube initialized with ingress"

# Деплой только recommender-app
deploy-recommender-app: check-minikube build-recommender-app load-recommender-app
	@echo "🛠 Deploying recommender-app..."
	kubectl apply -k $(INFRA_DIR)/k8s/overlays/production
	@echo "✅ Recommender-app deployed"

# Docker-compose команды для catalog-app с .env
up-catalog-compose:
	@echo "🚀 Starting catalog-app with docker compose..."
	@if [ -d "$(CATALOG_APP_DIR)" ]; then \
		if [ -f "$(CATALOG_APP_DIR)/.env" ]; then \
			echo "✅ Using .env file for docker compose"; \
			cd $(CATALOG_APP_DIR) && docker compose --env-file .env up -d; \
		else \
			echo "⚠️  .env file not found, using default environment"; \
			cd $(CATALOG_APP_DIR) && docker compose up -d; \
		fi; \
		echo "✅ catalog-app with PostgreSQL and MinIO started via docker compose"; \
		echo "📊 Check status: cd $(CATALOG_APP_DIR) && docker compose ps"; \
		echo "🌐 Catalog App: http://localhost:8080"; \
		echo "🐘 PostgreSQL: localhost:15433"; \
		echo "📦 MinIO API: http://localhost:19000"; \
		echo "🖥️  MinIO Console: http://localhost:19001"; \
	else \
		echo "❌ catalog-app directory not found at $(CATALOG_APP_DIR)"; \
	fi

down-catalog-compose:
	@echo "🛑 Stopping catalog-app docker-compose..."
	@if [ -d "$(CATALOG_APP_DIR)" ]; then \
		cd $(CATALOG_APP_DIR) && docker-compose down; \
		echo "✅ catalog-app docker-compose stopped"; \
	fi

logs-catalog-compose:
	@echo "📋 Showing catalog-app docker-compose logs..."
	@if [ -d "$(CATALOG_APP_DIR)" ]; then \
		cd $(CATALOG_APP_DIR) && docker-compose logs -f; \
	else \
		echo "❌ catalog-app directory not found"; \
	fi

status-catalog-compose:
	@echo "📊 catalog-app docker-compose status..."
	@if [ -d "$(CATALOG_APP_DIR)" ]; then \
		cd $(CATALOG_APP_DIR) && docker-compose ps; \
	else \
		echo "❌ catalog-app directory not found"; \
	fi

# Комбинированный запуск: Kubernetes + catalog-app через docker-compose
up-combined: up-catalog-compose deploy-all
	@echo "🏁 Combined infrastructure running!"
	@echo "💡 Run in separate terminal: minikube tunnel"
	@echo "🌐 Web App (K8s): http://web.local"
	@echo "📚 Catalog App (Docker): http://localhost:8080"
	@echo "🎯 Recommender App (K8s): http://recommender.local"
	@echo ""
	@echo "🐘 PostgreSQL (Docker): localhost:15433"
	@echo "📦 MinIO API (Docker): http://localhost:19000"
	@echo "🖥️  MinIO Console (Docker): http://localhost:19001"

down-combined: down-catalog-compose down
	@echo "🛑 Combined infrastructure stopped"

# Перестроение catalog-app
rebuild-catalog-app:
	@echo "🔨 Rebuilding catalog-app with docker-compose..."
	@if [ -d "$(CATALOG_APP_DIR)" ]; then \
		cd $(CATALOG_APP_DIR) && docker-compose build --no-cache; \
		docker tag $$(cd $(CATALOG_APP_DIR) && docker-compose images -q catalog-app) catalog-app:latest 2>/dev/null || \
		echo "⚠️  Could not tag catalog-app image"; \
	else \
		echo "⚠️  catalog-app directory not found"; \
	fi

.PHONY: deploy-all up down status clean clean-compose clean-all restart init-minikube deploy-recommender-app \
        up-catalog-compose down-catalog-compose logs-catalog-compose status-catalog-compose up-combined down-combined rebuild-catalog-app