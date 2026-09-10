#!/usr/bin/env bash
#
# deploy.sh
# Automatiza a publicação da aplicação PHP em uma VM Oracle Linux
# (Apache/httpd + PHP), reproduzindo os passos manuais do exercício.
#
# Uso:
#   chmod +x deploy.sh
#   sudo ./deploy.sh
#
# Requisitos: rodar como root (ou com sudo) em uma VM Oracle Linux / RHEL.

set -euo pipefail

# --- Configurações -----------------------------------------------------
APP_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_ROOT="/var/www/html"
WEB_USER="apache"
WEB_GROUP="apache"

# --- Funções auxiliares --------------------------------------------------
log() {
    echo -e "\n\033[1;34m==>\033[0m $1"
}

# --- 0. Checagem inicial -------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "Este script precisa ser executado como root (use: sudo ./deploy.sh)" >&2
    exit 1
fi

if [[ ! -f "${APP_SOURCE_DIR}/index.php" ]]; then
    echo "Não encontrei index.php em ${APP_SOURCE_DIR}." >&2
    echo "Rode este script de dentro da pasta que contém a aplicação." >&2
    exit 1
fi

# --- 1. Instalar Apache e PHP --------------------------------------------
log "Instalando httpd e php (se ainda não estiverem instalados)"
dnf install -y httpd php php-cli

# --- 2. Habilitar e iniciar o Apache --------------------------------------
log "Habilitando e iniciando o serviço httpd"
systemctl enable httpd
systemctl start httpd

# --- 3. Liberar a porta HTTP no firewall ---------------------------------
if command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
    log "Liberando o serviço HTTP no firewalld"
    firewall-cmd --permanent --add-service=http
    firewall-cmd --reload
else
    log "firewalld não está ativo — pulando ajuste de firewall"
fi

# --- 4. Copiar a aplicação para a pasta pública do Apache ----------------
log "Copiando arquivos da aplicação para ${WEB_ROOT}"
cp -v "${APP_SOURCE_DIR}"/*.php "${WEB_ROOT}/"

# --- 5. Ajustar posse e permissões ----------------------------------------
log "Ajustando owner e permissões dos arquivos"
chown -R "${WEB_USER}:${WEB_GROUP}" "${WEB_ROOT}"
chmod -R 755 "${WEB_ROOT}"

# --- 6. Ajustar contexto do SELinux ---------------------------------------
if command -v restorecon &> /dev/null; then
    log "Restaurando o contexto do SELinux em ${WEB_ROOT}"
    restorecon -Rv "${WEB_ROOT}"
else
    log "restorecon não encontrado — pulando ajuste de SELinux"
fi

# --- 7. Reiniciar o Apache para garantir que tudo foi aplicado -----------
log "Reiniciando o httpd"
systemctl restart httpd

# --- 8. Mostrar o resultado -----------------------------------------------
IP_ADDR=$(hostname -I | awk '{print $1}')
log "Deploy concluído!"
echo "Acesse no navegador: http://${IP_ADDR}/index.php"
