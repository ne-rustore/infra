#!/bin/bash

CATALOG_APP_DIR="../catalog-service"

echo "🔍 Checking .env file and environment..."

if [ -f "$CATALOG_APP_DIR/.env" ]; then
    echo "✅ .env file found at: $CATALOG_APP_DIR/.env"
    echo "📄 Content preview:"
    head -10 "$CATALOG_APP_DIR/.env"
    
    # Проверяем критичные переменные
    if grep -q "POSTGRES_PORT" "$CATALOG_APP_DIR/.env"; then
        echo "✅ POSTGRES_PORT found in .env"
    else
        echo "⚠️  POSTGRES_PORT not found in .env, using default: 15433"
    fi
    
    if grep -q "PORT" "$CATALOG_APP_DIR/.env"; then
        echo "✅ PORT found in .env"
    else
        echo "⚠️  PORT not found in .env, using default: 8080"
    fi
else
    echo "❌ .env file not found at: $CATALOG_APP_DIR/.env"
    echo "💡 Create .env file with:"
    echo "   POSTGRES_PORT=15433"
    echo "   MINIO_API_PORT=19000"
    echo "   MINIO_CONSOLE_PORT=19001"
    echo "   PORT=8080"
    echo "   MINIO_BUCKET=apps-media"
    echo "   S3_BASE_URL=http://minio:9000"
fi