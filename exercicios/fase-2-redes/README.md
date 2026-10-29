# Fase 2 — Redes e segurança

Exercícios da Fase 2 da trilha de estudos: seguir o caminho de uma requisição do cliente até o servidor e descobrir em qual camada está o problema.

Os desafios continuam no `servidor1` da [Fase 1](../fase-1-linux/) (Apache, IP fixo `192.168.50.10`, firewall e SSH com chave).

| Desafio | Tópicos |
| --- | --- |
| [Desafio 2.1 — O caminho de uma requisição](desafio-01-caminho-requisicao/) | `dig`, `ss -tulnp`, `curl -v`, `tcpdump` (aperto de mão do TCP, ICMP), catálogo de sintomas por camada |
| [Desafio 2.2 — Proxy reverso: o Apache atrás do Nginx](desafio-02-proxy-reverso-nginx/) | Nginx (`proxy_pass`, `default_server`, `nginx -t`), `Listen` no localhost, `502 Bad Gateway`, booleans do SELinux (`httpd_can_network_relay`), `X-Forwarded-For` e `mod_remoteip`, `server_tokens`, defesa em profundidade |
| [Desafio 2.3 — HTTPS com uma CA própria](desafio-03-https/) | CA própria com `openssl` (chave, CSR, SAN, `x509 -req`), `listen 443 ssl`, redirecionamento 301, `firewall-cmd --add-service=https`, `hosts` e `certutil` no Windows, revogação, `openssl s_client`, SNI visível no `tcpdump` |
| [Desafio 2.4 — Balanceamento de carga com Nginx](desafio-04-balanceamento/) | `upstream`, round-robin, `add_header X-Backend $upstream_addr`, failover e verificação passiva de saúde, `502` / `no live upstreams`, `weight`, `backup`, rótulos de porta do SELinux (`semanage port -l`) |
