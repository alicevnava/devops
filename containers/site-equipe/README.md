# site-equipe

O "Site da equipe" empacotado numa imagem de container (Nginx 1.31).

## Construir e rodar

    podman build -t site-equipe:1.1 .
    podman run -d --name site-equipe -p 8090:80 localhost/site-equipe:1.1
    curl http://localhost:8090

## Como serviço do systemd (Quadlet, sem root)

    mkdir -p ~/.config/containers/systemd
    cp site-equipe.container ~/.config/containers/systemd/
    systemctl --user daemon-reload
    systemctl --user start site-equipe.service
    sudo loginctl enable-linger $USER

O `enable-linger` faz o serviço subir no boot, mesmo sem login.
