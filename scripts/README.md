# Scripts

Scripts de automação da Fase 3 (Git, Bash e Python) da trilha de estudos.

| Script | O que faz |
| --- | --- |
| [verifica-servicos.sh](verifica-servicos.sh) | Verifica se os serviços estão ativos (padrão: `nginx httpd sshd`, ou os passados como argumento). Sai com 0 se todos estão no ar e 1 se algum falhou |
| [analisa-log.sh](analisa-log.sh) | Relatório de um log de acesso do Nginx: total de pedidos, IPs que mais acessam, códigos HTTP, páginas mais pedidas e erros 4xx/5xx. Uso: `analisa-log.sh <arquivo de log>` |
| [backup.sh](backup.sh) | Backup de `/srv/site` e `/dados/site` em `/backup`, com data e hora no nome, verificação do arquivo gerado e rotação mantendo os 5 mais recentes. Só apaga os antigos se o novo for criado e lido sem erro. Instalado como `/usr/local/bin/backup-site.sh`, chamado pelo `backup-site.timer` |
| [backup.py](backup.py) | O mesmo backup do `backup.sh`, reescrito em Python: chama o `tar` com `subprocess`, verifica com `tarfile` e faz a rotação com `pathlib`, mantendo os 5 mais recentes |
| [relatorio_github.py](relatorio_github.py) | Relatório dos repositórios listados em [relatorio-github.yaml](relatorio-github.yaml), consultando a API do GitHub: linguagem, última atualização e PRs aceitos. Salva o resultado em JSON. Usa o token da variável `GITHUB_TOKEN`, se existir. Uso: `relatorio_github.py <arquivo de configuração>` |
