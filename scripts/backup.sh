#!/bin/bash
# Backup do projeto site, com verificação e rotação por quantidade.
# Uso: sudo backup.sh

ORIGENS="/srv/site /dados/site"
DESTINO="/backup"
PREFIXO="site"
MANTER=5
umask 077

log() {
    echo "$(date '+%F %T') $1"
}

fazer_backup() {
    ARQUIVO="$DESTINO/$PREFIXO-$(date +%F_%H%M%S).tar.gz"
    log "Criando $ARQUIVO"
    if ! tar --acls --selinux --xattrs -czpf "$ARQUIVO" $ORIGENS; then
        log "ERRO: o tar falhou"
        rm -f "$ARQUIVO"
        exit 1
    fi
}

verificar_backup() {
    if ! tar -tzf "$ARQUIVO" > /dev/null; then
        log "ERRO: o backup não pôde ser lido"
        rm -f "$ARQUIVO"
        exit 1
    fi
    log "Backup verificado: $(tar -tzf "$ARQUIVO" | wc -l) itens"
}

rotacionar() {
    ANTIGOS=$(ls -1t "$DESTINO/$PREFIXO"-20*.tar.gz | tail -n +$((MANTER + 1)))
    for antigo in $ANTIGOS; do
        log "Apagando $antigo"
        rm -f "$antigo"
    done
}

if [ "$(id -u)" -ne 0 ]; then
    log "ERRO: rode como root (sudo)"
    exit 1
fi

log "Início do backup"

mkdir -p "$DESTINO"
fazer_backup
verificar_backup
rotacionar
log "Fim do backup"
