# Fase 3 — Git, Bash e Python

Exercícios da Fase 3 da trilha de estudos: transformar tarefas manuais em tarefas repetíveis e versionadas.

Os desafios rodam no `servidor1` da [Fase 1](../fase-1-linux/). Os scripts produzidos ficam na pasta [`scripts/`](../../scripts/) deste repositório e entram na `main` por pull request.

| Desafio | Tópicos |
| --- | --- |
| [Desafio 3.1 — Git na prática](desafio-01-git/) | `git config`, chave SSH para o GitHub, `clone`, branch, `add`/`commit`/`push`, pull request, `pull` (fast-forward), conflito de merge, `log --graph`, `show`, `diff`, `restore`, `revert` x `reset` |
| [Desafio 3.2 — Bash I: o verificador de serviços](desafio-02-bash-verifica-servicos/) | códigos de saída (`$?`, `exit`), shebang, `chmod +x`, variáveis, `if`, `for`, `[ ... ]` (`-eq`, `-gt`), aritmética `$(( ))`, argumentos (`$#`, `$@`), `systemctl is-active --quiet`, recuperar commit com o hash |
| [Desafio 3.3 — Texto no terminal: o que o log do Nginx conta](desafio-03-texto-log-nginx/) | formato do log do Nginx, campos do `awk` (`$1`, `$7`, `$9`), `sort \| uniq -c \| sort -rn`, `head`, `wc -l`, filtro `awk '$9 >= 400'`, `tr`, rotação de logs, script com validação de argumento (`-ne`, `! -f`) |
| [Desafio 3.4 — Bash II: o backup completo](desafio-04-bash-backup/) | funções (`nome() { }`), `id -u`, `date '+%F %T'`, `if ! comando`, verificação com `tar -tzf`, rotação por quantidade (`ls -1t \| tail -n +N`), expansão do `*` com `sudo` (`sudo bash -c`), `install -m 700`, script do repositório no timer do systemd, `journalctl -u` |
| [Desafio 3.5 — Python para automação: o backup reescrito](desafio-05-python-backup/) | `subprocess.run`, `tarfile`, `try`/`except`, `with`, `pathlib` (`glob`, `stat`, `unlink`), `sorted` com `key=lambda`, fatiamento, `os.geteuid`, `os.umask`, `sys.exit`, f-strings, PEP 8, comparação Bash x Python |
