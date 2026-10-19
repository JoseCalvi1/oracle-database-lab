#!/usr/bin/env bash
# scripts/deployment/env/09-verificar-herramientas.sh
echo "== Verificando Java =="
java -version 2>&1
echo
echo "== Verificando SQLcl =="
sql -V
