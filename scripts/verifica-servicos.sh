#!/bin/bash
# Verifica se os serviços do servidor estão no ar.
# Saída: 0 se todos estão ativos, 1 se algum falhou.

servicos="nginx httpd sshd"
if [ "$#" -gt 0 ]; then
    servicos="$@"
fi

falhas=0

for servico in $servicos; do
    if systemctl is-active --quiet "$servico"; then
        echo "$servico: OK"
    else
        echo "$servico: FALHOU"
        falhas=$((falhas + 1))
    fi
done

echo "Falhas: $falhas"

if [ "$falhas" -eq 0 ]; then
    exit 0
else
    exit 1
fi
