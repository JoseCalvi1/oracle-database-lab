#!/usr/bin/env bash
# scripts/deployment/env/06-esperar-db.sh
source scripts/deployment/env/00-config.sh

echo "== Esperando a que Oracle Database este HEALTHY =="
echo "Este proceso toma entre 2 y 5 minutos..."

while true; do
  STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONT_NAME" 2>/dev/null || echo "error")
  
  if [ "$STATUS" = "healthy" ]; then
    echo -e "\n¡Base de datos lista! Estado: $STATUS"
    docker ps --filter "name=$CONT_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    break
  elif [ "$STATUS" = "unhealthy" ]; then
    echo -e "\nError: La base de datos esta UNHEALTHY."
    docker logs --tail 20 "$CONT_NAME"
    exit 1
  else
    echo -n "."
    sleep 5
  fi
done
