#!/usr/bin/env python3
"""Backup do projeto site, com verificação e rotação por quantidade.

Uso: sudo backup.py
"""

import os
import subprocess
import sys
import tarfile
from datetime import datetime
from pathlib import Path

ORIGENS = ["/srv/site", "/dados/site"]
DESTINO = "/backup"
PREFIXO = "site"
MANTER = 5


def log(mensagem):
    agora = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"{agora} {mensagem}", flush=True)


def fazer_backup():
    data = datetime.now().strftime("%Y-%m-%d_%H%M%S")
    arquivo = f"{DESTINO}/{PREFIXO}-{data}.tar.gz"
    log(f"Criando {arquivo}")
    comando = ["tar", "--acls", "--selinux", "--xattrs", "-czpf", arquivo] + ORIGENS
    resultado = subprocess.run(comando)
    if resultado.returncode != 0:
        log("ERRO: o tar falhou")
        Path(arquivo).unlink(missing_ok=True)
        sys.exit(1)
    return arquivo


def verificar_backup(arquivo):
    try:
        with tarfile.open(arquivo, "r:gz") as tar:
            itens = tar.getnames()
    except (tarfile.TarError, EOFError, OSError) as erro:
        log(f"ERRO: o backup não pôde ser lido ({erro})")
        Path(arquivo).unlink(missing_ok=True)
        sys.exit(1)
    log(f"Backup verificado: {len(itens)} itens")

def rotacionar():
    backups = sorted(
        Path(DESTINO).glob(f"{PREFIXO}-20*.tar.gz"),
        key=lambda caminho: caminho.stat().st_mtime,
        reverse=True,
    )
    for antigo in backups[MANTER:]:
        log(f"Apagando {antigo}")
        antigo.unlink()

def main():
    if os.geteuid() != 0:
        log("ERRO: rode como root (sudo)")
        sys.exit(1)

    log("Início do backup")
    os.umask(0o077)
    os.makedirs(DESTINO, exist_ok=True)
    arquivo = fazer_backup()
    verificar_backup(arquivo)
    rotacionar()
    log("Fim do backup")


if __name__ == "__main__":
    main()
