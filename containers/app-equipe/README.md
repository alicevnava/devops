# app-equipe

Aplicação em Python (responde em JSON com o nome do container) atrás de um Nginx, numa rede do Podman.

    curl ──► :8092 ──► proxy (Nginx) ──rede equipe──► app1 / app2 (Python :5000)

## Subir e derrubar

    podman-compose up -d
    curl http://localhost:8092/
    podman-compose down

- A aplicação não publica porta: só o proxy fica acessível.
- `app1` e `app2` atendem pelo mesmo nome (`app`) na rede, e o Nginx divide os pedidos entre os dois.
- A aplicação trata o SIGTERM, para parar na hora com `podman stop`.

## Imagem publicada

A imagem está em `ghcr.io/alicevnava/app-equipe` (pública), baseada em Python 3.12 Alpine (51 MB), com healthcheck.

    podman run -d --name app -p 5000:5000 ghcr.io/alicevnava/app-equipe:1.2

Para construir e publicar uma versão nova (o `--format docker` é necessário para o healthcheck ser gravado):

    podman build --format docker -t ghcr.io/alicevnava/app-equipe:<versão> app
    podman login ghcr.io -u alicevnava
    podman push ghcr.io/alicevnava/app-equipe:<versão>
    podman logout ghcr.io
