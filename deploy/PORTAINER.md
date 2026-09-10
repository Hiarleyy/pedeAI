# Deploy PedeAI no Portainer

## 1. Publicar a imagem

Na raiz do repositório, construa e publique uma tag imutável no registry usado pelo servidor:

```bash
docker build -t ghcr.io/sua-organizacao/pedeai:2026.09.10 .
docker push ghcr.io/sua-organizacao/pedeai:2026.09.10
```

Use a tag publicada em `PEDEAI_IMAGE`; não monte o código-fonte como volume em produção.

## 2. Criar a Stack

No Portainer, escolha **Stacks > Add stack**, cole o conteúdo de `deploy/portainer-stack.yml` e cadastre as variáveis de `deploy/.env.example` em **Environment variables**. Substitua todos os valores `replace-*`, use uma `SECRET_KEY_BASE` aleatória e mantenha PostgreSQL/Redis apenas na rede privada da Stack.

A Stack expõe a porta `3000` somente dentro das redes Docker; o acesso público acontece pelo Traefik. O serviço `migrate` executa `rails db:prepare` uma vez; confirme que terminou com código 0 antes de colocar `web` e `worker` em serviço.

### 2.1 Dominio e HTTPS

O ambiente de producao usa `pedeai.insilico.cloud` por padrao. Mantenha estas variaveis na Stack:

```dotenv
APP_HOST=pedeai.insilico.cloud
CORS_ORIGINS=https://pedeai.insilico.cloud
RAILS_ASSUME_SSL=true
RAILS_FORCE_SSL=true
```

No provedor DNS, crie um registro `A` para `pedeai.insilico.cloud` apontando para o IP público do servidor. No proxy reverso, emita o certificado TLS para esse domínio e encaminhe o tráfego para a porta interna `3000`. Preserve os cabeçalhos `Host`, `X-Forwarded-For` e `X-Forwarded-Proto`.

Exemplo de encaminhamento com Nginx:

```nginx
server {
  listen 443 ssl http2;
  server_name pedeai.insilico.cloud;

  location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
  }
}
```


O certificado deve ser gerenciado pelo proxy (por exemplo, Nginx Proxy Manager, Traefik ou Certbot), nao pela aplicacao Rails.

### 2.2 Traefik existente

A Stack conecta somente o serviço `web` à rede externa do Traefik. Para o ambiente atual, configure:

```dotenv
TRAEFIK_NETWORK=plataforma-redacao-web
TRAEFIK_ENTRYPOINT=websecure
TRAEFIK_CERTRESOLVER=letsencryptresolver
```

Antes do deploy, confirme em **Networks** no Portainer que `plataforma-redacao-web` é uma rede `overlay` anexável ao mesmo Swarm do Traefik. As labels ficam em `deploy.labels`, portanto o Traefik deve utilizar o provider Swarm e observar os serviços desse cluster.

Ao atualizar uma Stack já existente, substitua integralmente o conteúdo antigo pelo arquivo atual e habilite **Re-pull image and redeploy**. A configuração correta não publica a porta `3000` no host; ela fica acessível apenas ao Traefik pela rede externa.

Se o resolver configurado no Traefik tiver outro nome, altere `TRAEFIK_CERTRESOLVER`. Após atualizar a Stack, valide:

```bash
curl -I https://pedeai.insilico.cloud/up
```

O retorno esperado é `200`. Um `404` com cabeçalho do Traefik/Cloudflare indica que a regra de roteamento ainda não foi carregada; verifique a rede externa, o provider Swarm e os nomes do entrypoint/resolver.

Confira a revisão efetivamente aplicada no Swarm usando o nome completo do serviço (nome da Stack + nome do serviço):

```bash
docker service ls | grep pedeai
docker service inspect pedeai_web --format '{{json .Spec.Labels}}'
docker service inspect pedeai_web --format '{{range .Spec.TaskTemplate.Networks}}{{.Target}}{{println}}{{end}}'
docker service inspect pedeai_web --format '{{json .Endpoint.Spec.Ports}}'
```

O último comando deve retornar `null`. Se exibir uma publicação `3000:3000`, a Stack antiga ainda está ativa. As labels do segundo comando devem conter `Host(`pedeai.insilico.cloud`)`, `websecure`, `letsencryptresolver` e `plataforma-redacao-web`.

## 3. Atualizar ou fazer rollback

1. Publique uma nova tag e altere somente `PEDEAI_IMAGE` no Stack.
2. Execute/recrie `migrate` e confirme os logs.
3. Verifique `GET /up`, os logs de `web` e o consumo de filas em `worker`.
4. Se a nova versão não ficar saudável, retorne `PEDEAI_IMAGE` à tag anterior e reimplante.

Não remova os volumes `pedeai_postgres_data` ou `pedeai_redis_data` durante uma atualização.

## 4. Backup e restore

Faça backup periódico do PostgreSQL antes de migrações:

```bash
docker exec <container-db> pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > backup.sql
```

Restaure em uma instância de manutenção com `psql` e valide `/up` antes de direcionar tráfego. O Redis armazena filas transitórias; preserve o volume para reinícios, mas trate o PostgreSQL como fonte dos dados de negócio.

## 5. Segurança e troubleshooting

- Nunca publique as portas 5432 ou 6379.
- Nunca registre tokens, senhas ou payloads de cardápio nos logs.
- Use a rotação de logs configurada na Stack e o backup externo do volume PostgreSQL.
- Se `web` estiver unhealthy, consulte primeiro `db`, `redis` e as variáveis obrigatórias; o health check da aplicação usa `/up`.
