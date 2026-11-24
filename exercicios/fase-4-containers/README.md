# Fase 4 — Containers

Exercícios da Fase 4 da trilha de estudos: empacotar aplicações em containers e rodá-las num cluster Kubernetes.

Os desafios rodam no `servidor1` da [Fase 1](../fase-1-linux/), com o **Podman** (o padrão do Rocky Linux), sem root. Os arquivos dos containers ficam em [`containers/`](../../containers/) e entram na `main` por pull request.

| Desafio | Tópicos |
| --- | --- |
| [Desafio 4.1 — O "Site da equipe" num container](desafio-01-site-em-container/) | Podman rootless, imagem x container, registro e tag, `podman run -d -p --name`, Containerfile (`FROM`, `COPY`, `EXPOSE`), `podman build`, versão fixada e mantida, camadas, `ps`/`logs`/`exec`/`stop`/`start`/`rm`/`rmi`, PID 1, volume com SELinux (`:Z`, `container_file_t`, `dontaudit`), Quadlet e `loginctl enable-linger` |
