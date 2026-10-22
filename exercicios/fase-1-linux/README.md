# Fase 1 — Linux sólido

Exercícios da Fase 1 da trilha de estudos: administração de servidores Linux, com base no conteúdo do RHCSA.

Cada desafio parte de um cenário, como acontece no trabalho, e termina com testes que provam que o resultado está certo.

| Desafio | Tópicos |
| --- | --- |
| [Desafio 1 — Usuários, grupos e sudo](desafio-01-usuarios-grupos-sudo/) | `useradd`, `passwd`, `groupadd`, `usermod`, `chgrp`, `chmod` numérico, grupo `wheel` |
| [Desafio 2 — Pasta compartilhada](desafio-02-pasta-compartilhada/) | Setgid em diretório, umask, ACL (`setfacl` e `getfacl`), `dnf provides` |
| [Desafio 3 — SELinux: o site que não abre](desafio-03-selinux-apache/) | Apache (`httpd`), `systemctl`, rótulos do SELinux (`ls -Z`), `ausearch`, `restorecon`, `mv` x `cp` |
| [Desafio 4 — Processos e sinais: o servidor lento](desafio-04-processos-sinais/) | `top`, `ps`, PID, prioridade (`renice`), sinais (`kill`, SIGTERM, SIGKILL, SIGINT), `nohup` e `&` |
| [Desafio 5 — systemd e journalctl: o serviço que não sobe](desafio-05-systemd-journalctl/) | Arquivo de unidade (`.service`), `systemctl start`/`enable`, `Restart=on-failure`, `journalctl` (`-u`, `--since`, `-b`, `--list-boots`), journal permanente |
