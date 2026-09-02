# Linux para DevOps — Trilha de Treinamento

Conteúdo básico/intermediário para quem está começando. O objetivo não é decorar comandos, é entender **o que está acontecendo por baixo** — permissões, processos, rede, arquivos — porque isso é a base de tudo que vem depois (Docker, Kubernetes, CI/CD, troubleshooting em produção).

---

## 1. Por que Linux importa em DevOps

A imensa maioria dos servidores, containers e pipelines de CI/CD roda em Linux. Imagens Docker são Linux. Nós de Kubernetes são Linux. Scripts de automação (Ansible, Terraform provisioners) assumem um shell Linux. Não dá para ser DevOps sem fluência aqui.

---

## 2. Distribuições (distros)

Não precisa dominar todas, mas é bom saber que existem "famílias":

- **Debian/Ubuntu** — gerenciador de pacotes `apt`. Muito usada em servidores web e containers.
- **RHEL/CentOS/Rocky/Alma** — gerenciador `yum`/`dnf`. Comum em ambientes corporativos.
- **Alpine** — minimalista, usada em imagens Docker (`apk`).

O que muda entre elas: gerenciador de pacotes e alguns caminhos de arquivo. Os conceitos (processos, permissões, systemd) são os mesmos.

---

## 3. Sistema de arquivos e estrutura

```
/            raiz
/bin, /usr/bin   binários/executáveis
/etc         arquivos de configuração
/var         dados variáveis (logs, cache, filas)
/var/log     logs do sistema — primeiro lugar pra olhar quando algo quebra
/home        diretórios dos usuários
/tmp         arquivos temporários
/opt         software de terceiros
/proc, /sys  interfaces virtuais para o kernel (processos, hardware)
```

**Tudo é arquivo** em Linux — dispositivos, sockets, processos (via `/proc`) são representados como arquivos. Esse é o conceito mais importante da filosofia Unix.

---

## 4. Comandos essenciais (navegação e arquivos)

| Comando | Uso |
|---|---|
| `pwd` | mostra diretório atual |
| `ls -la` | lista arquivos, incluindo ocultos, com detalhes |
| `cd` | navega entre diretórios |
| `cat`, `less`, `tail -f` | ler arquivos (tail -f para acompanhar logs em tempo real) |
| `cp`, `mv`, `rm` | copiar, mover/renomear, remover |
| `mkdir -p` | criar diretórios (com pais, se necessário) |
| `find /path -name "*.log"` | buscar arquivos |
| `grep -r "erro" /var/log` | buscar texto dentro de arquivos |
| `ln -s origem destino` | criar link simbólico |
| `df -h` | espaço em disco |
| `du -sh *` | tamanho de pastas/arquivos |

---

## 5. Permissões e usuários

Todo arquivo tem dono (owner), grupo (group) e permissões para "outros" (others). Cada um tem **r**ead, **w**rite, e**x**ecute.

```
-rwxr-xr-- 1 usuario grupo  arquivo.sh
 │└┬┘└┬┘└┬┘
 │ │  │  └─ outros: leitura apenas
 │ │  └──── grupo: leitura e execução
 │ └─────── dono: leitura, escrita, execução
 └───────── tipo (- arquivo, d diretório, l link)
```

- `chmod 755 arquivo` — altera permissões (numérico: r=4, w=2, x=1)
- `chown usuario:grupo arquivo` — muda dono/grupo
- `sudo` — executa comando como outro usuário (normalmente root)
- **root** é o superusuário — cuidado, tem acesso irrestrito. Em produção, prefira usuários com privilégios mínimos necessários (princípio do menor privilégio).

---

## 6. Processos

- `ps aux` — lista processos em execução
- `top` / `htop` — monitor interativo de processos e uso de CPU/memória
- `kill -9 PID` — mata um processo (força)
- `systemctl status <serviço>` — status de um serviço gerenciado pelo systemd
- `systemctl start/stop/restart/enable <serviço>` — controlar serviços

**systemd** é o sistema de inicialização (init system) padrão nas distros modernas. Ele gerencia serviços (unidades `.service`), ordem de boot e dependências.

---

## 7. Rede básica (o essencial, complementa o README de Redes)

- `ip a` / `ip addr` — mostra interfaces e IPs (substitui o antigo `ifconfig`)
- `ping host` — testa conectividade
- `curl -I https://exemplo.com` — testa uma requisição HTTP
- `netstat -tulnp` ou `ss -tulnp` — mostra portas abertas e processos escutando
- `ssh usuario@host` — conecta remotamente via SSH

---

## 8. Redirecionamento, pipes e scripts

```bash
comando > arquivo.txt     # redireciona saída, sobrescreve
comando >> arquivo.txt    # redireciona saída, adiciona ao final
comando1 | comando2       # pipe: saída de um vira entrada do outro
comando 2> erros.log      # redireciona apenas stderr
```

Exemplo prático: `ps aux | grep nginx` — lista processos e filtra pelos que contêm "nginx".

**Shell script básico:**
```bash
#!/bin/bash
set -euo pipefail   # boas práticas: para em erro, variável não definida, e falha em pipes

for arquivo in *.log; do
    echo "Processando $arquivo"
done
```

---

## 9. Variáveis de ambiente

```bash
export MINHA_VAR="valor"
echo $MINHA_VAR
env          # lista todas as variáveis
```
Usado constantemente em CI/CD e containers para configuração (ex: `DATABASE_URL`, `API_KEY`).

---

## 10. Gerenciamento de pacotes

```bash
# Debian/Ubuntu
apt update && apt install -y nginx

# RHEL/CentOS
dnf install -y nginx
```

---

## 11. Logs e troubleshooting

- `journalctl -u <serviço> -f` — logs de um serviço gerenciado por systemd, em tempo real
- `/var/log/syslog` ou `/var/log/messages` — log geral do sistema
- `dmesg` — mensagens do kernel (útil para problemas de hardware/driver)

Fluxo básico de troubleshooting: **o que aconteceu → quando → em qual processo/serviço → o que os logs dizem → o que mudou recentemente**.

---

## 12. Ferramentas úteis do dia a dia

- `vim` ou `nano` — editores de texto no terminal
- `tar -czvf arquivo.tar.gz pasta/` — compactar; `tar -xzvf` para extrair
- `wget` / `curl` — baixar arquivos
- `cron` / `crontab -e` — agendar tarefas recorrentes
- `screen` / `tmux` — sessões de terminal persistentes (sobrevivem à desconexão SSH)

---

## 13. Para praticar

1. Suba uma VM ou container Ubuntu e navegue usando apenas o terminal.
2. Crie um usuário, dê permissões específicas a um diretório, teste o acesso.
3. Escreva um script que monitore o uso de disco e alerte se passar de 80%.
4. Explore `/var/log` e identifique o que cada log representa.
5. Configure um serviço simples (ex: nginx) e gerencie com `systemctl`.

## 14. Onde seguir aprendendo

- [Roadmap.sh — Linux](https://roadmap.sh/) (base de referência deste conteúdo)
- Documentação oficial da distro escolhida (`man <comando>` sempre é seu amigo)
