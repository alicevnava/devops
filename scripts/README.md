# Scripts

Scripts de automação da Fase 3 (Git, Bash e Python) da trilha de estudos.

| Script | O que faz |
| --- | --- |
| [verifica-servicos.sh](verifica-servicos.sh) | Verifica se os serviços estão ativos (padrão: `nginx httpd sshd`, ou os passados como argumento). Sai com 0 se todos estão no ar e 1 se algum falhou |
| [analisa-log.sh](analisa-log.sh) | Relatório de um log de acesso do Nginx: total de pedidos, IPs que mais acessam, códigos HTTP, páginas mais pedidas e erros 4xx/5xx. Uso: `analisa-log.sh <arquivo de log>` |
