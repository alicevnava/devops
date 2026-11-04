#!/bin/bash
# Gera um relatório a partir de um log de acesso do Nginx.
# Uso: analisa-log.sh <arquivo de log>

if [ "$#" -ne 1 ]; then
    echo "Uso: $0 <arquivo de log>"
    exit 1
fi

log="$1"

if [ ! -f "$log" ]; then
    echo "Arquivo não encontrado: $log"
    exit 1
fi

echo "Total de pedidos:"
wc -l < "$log"

echo "IPs que mais acessam:"
awk '{print $1}' "$log" | sort | uniq -c | sort -rn | head -5

echo "Códigos HTTP:"
awk '{print $9}' "$log" | sort | uniq -c | sort -rn

echo "Páginas mais pedidas:"
awk '{print $7}' "$log" | sort | uniq -c | sort -rn | head -5

echo "Erros (4xx e 5xx):"
awk '$9 >= 400 {print $9, $7}' "$log"
