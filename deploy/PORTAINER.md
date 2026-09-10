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

A Stack expõe somente `HTTP_PORT` para a aplicação. O serviço `migrate` executa `rails db:prepare` uma vez; confirme que terminou com código 0 antes de colocar `web` e `worker` em serviço.

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
