# Fase 1 — Linux sólido

Exercícios da Fase 1 da trilha de estudos: administração de servidores Linux, com base no conteúdo do RHCSA.

Cada desafio parte de um cenário, como acontece no trabalho, e termina com testes que provam que o resultado está certo.

## Como refazer

- **Faça os desafios em ordem, na mesma VM.** Eles dependem uns dos outros:

| Desafio | Usa o que foi criado em |
| --- | --- |
| 2 — Pasta compartilhada | 1 (usuários `ana` e `bruno`, grupo `site`, `/srv/site`) |
| 4 — Processos e sinais | 1 (usuário `bruno`) |
| 8 — Rede no servidor | 3 (Apache nas portas 80 e 8080) |

- **Ambiente:** Rocky Linux 10 (Minimal Install) numa VM, com um usuário administrador (membro do grupo `wheel`). Os desafios foram feitos no Hyper-V; em outro virtualizador, os passos do Linux são os mesmos.
- **Faça um ponto de verificação (snapshot) da VM** antes de cada desafio, para poder voltar se algo der errado.
- **Valores entre `< >`** nos comandos, como `<PID_DO_YES>` ou `<UUID_DO_LVSITE>`, mudam em cada máquina: troque pelo valor que aparecer no seu terminal. As saídas mostradas nos READMEs são exemplos reais, e os números delas (PIDs, UUIDs, IDs de transação, IPs do DHCP) serão diferentes no seu ambiente.
- **A tabela "Erros que aconteceram"** de cada desafio mostra comandos que **falharam**, com a correção. Para refazer, siga só o **Passo a passo**.

| Desafio | Tópicos |
| --- | --- |
| [Desafio 1 — Usuários, grupos e sudo](desafio-01-usuarios-grupos-sudo/) | `useradd`, `passwd`, `groupadd`, `usermod`, `chgrp`, `chmod` numérico, grupo `wheel` |
| [Desafio 2 — Pasta compartilhada](desafio-02-pasta-compartilhada/) | Setgid em diretório, umask, ACL (`setfacl` e `getfacl`), `dnf provides` |
| [Desafio 3 — SELinux: o site que não abre](desafio-03-selinux-apache/) | Apache (`httpd`), `systemctl`, rótulos do SELinux (`ls -Z`), `ausearch`, `restorecon`, `mv` x `cp` |
| [Desafio 4 — Processos e sinais: o servidor lento](desafio-04-processos-sinais/) | `top`, `ps`, PID, prioridade (`renice`), sinais (`kill`, SIGTERM, SIGKILL, SIGINT), `nohup` e `&` |
| [Desafio 5 — systemd e journalctl: o serviço que não sobe](desafio-05-systemd-journalctl/) | Arquivo de unidade (`.service`), `systemctl start`/`enable`, `Restart=on-failure`, `journalctl` (`-u`, `--since`, `-b`, `--list-boots`), journal permanente |
| [Desafio 6 — Pacotes com dnf: o servidor sem internet](desafio-06-pacotes-dnf/) | `dnf info`, `rpm -qf`/`-qc`/`-ql`, `dnf history` e `undo`, repositório local a partir da ISO (`mount`, `.repo`, GPG), `--repo` |
| [Desafio 7 — Discos, LVM e fstab: o espaço que acabou](desafio-07-discos-lvm-fstab/) | `fdisk` (GPT), `pvcreate`, `vgcreate`, `lvcreate`, `mkfs.xfs`, `/etc/fstab` com UUID, `mount -a`, `lvextend -r`, swap (`mkswap`, `swapon`) |
| [Desafio 8 — Rede no servidor: o IP que não para quieto](desafio-08-rede/) | `nmcli` (IP fixo, conexões), `hostnamectl`, `/etc/hosts`, `getent`, `firewall-cmd` (serviços, portas, `--permanent`), rede interna no Hyper-V |
