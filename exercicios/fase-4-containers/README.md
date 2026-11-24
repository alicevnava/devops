# Fase 4 — Containers

Exercícios da Fase 4 da trilha de estudos: empacotar aplicações em containers e rodá-las num cluster Kubernetes.

Os desafios rodam no `servidor1` da [Fase 1](../fase-1-linux/), com o **Podman** (o padrão do Rocky Linux), sem root. Os arquivos dos containers ficam em [`containers/`](../../containers/) e entram na `main` por pull request.

| Desafio | Tópicos |
| --- | --- |
| [Desafio 4.1 — O "Site da equipe" num container](desafio-01-site-em-container/) | Podman rootless, imagem x container, registro e tag, `podman run -d -p --name`, Containerfile (`FROM`, `COPY`, `EXPOSE`), `podman build`, versão fixada e mantida, camadas, `ps`/`logs`/`exec`/`stop`/`start`/`rm`/`rmi`, PID 1, volume com SELinux (`:Z`, `container_file_t`, `dontaudit`), Quadlet e `loginctl enable-linger` |
| [Desafio 4.2 — Dois containers numa rede, depois com Compose](desafio-02-app-proxy-compose/) | aplicação Python em container (`USER`, `CMD`), `podman network`, DNS dos containers (`getent`), proxy pelo nome do container, volume de um arquivo, IPv4 x IPv6, SIGTERM e o PID 1 (`Exited (137)`), `podman-compose` (`services`, `depends_on`, `aliases`), duas cópias com round-robin, `.gitignore` |
| [Desafio 4.3 — Imagens melhores e registro](desafio-03-imagem-e-registro/) | `podman history` e camadas, base `slim` x `alpine` (124 → 51 MB), `LABEL` OCI, `HEALTHCHECK` com `--format docker`, `healthy`/`unhealthy` com SIGSTOP, `podman login`/`tag`/`push`/`pull`, GitHub Container Registry (token classic, pacote público), a mesma imagem na `servidor2` |
