# PedeAI API

API Rails multi-restaurante para cardápios, pedidos de delivery e atendimento presencial. A versão canônica usa o slug do restaurante em todo recurso operacional:

```text
/api/v1/restaurants/:restaurant_slug/<recurso>
```

## Executar com Docker

```bash
docker compose up --build
docker compose exec api bundle exec rails db:seed
```

- Swagger UI: http://localhost:3000/docs
- OpenAPI: http://localhost:3000/openapi.yaml
- Health check: http://localhost:3000/up
- PedeAi Control: http://localhost:3000/control

## Operações globais

Somente operações que ainda não possuem contexto de restaurante ficam fora da rota com slug:

- `POST /api/v1/session`: autenticação administrativa. A resposta inclui token, usuário e restaurante com seu slug.
- `POST /api/internal/session`: autentica um operador global separado dos usuÃ¡rios de tenant.
- `/api/internal/restaurants`: lista e administra restaurantes com token global; a criaÃ§Ã£o inclui atomicamente o primeiro `superAdmin`.
- `/api/internal/audit_events` e `/api/internal/diagnostics`: auditoria e diagnÃ³stico protegidos por permissÃ£o.

O antigo `POST /api/v1/restaurants` foi removido e nÃ£o aceita onboarding anÃ´nimo.

### Ambiente DEV do Control

Inicie API, worker, PostgreSQL e Redis com `docker compose -f docker-compose.dev.yml up --build`. O operador inicial vem de `PLATFORM_OWNER_NAME`, `PLATFORM_OWNER_EMAIL` e `PLATFORM_OWNER_PASSWORD`; altere os valores locais antes de compartilhar o ambiente. A senha nunca Ã© impressa pelo seed.

`docker compose -f docker-compose.dev.yml exec api bundle exec rails db:seed` atualiza somente o operador global. Use `bundle exec rails demo:seed` explicitamente para carregar Forno & Massa e Burger Lab, ou `bundle exec rails demo:reset` para recriar somente esses tenants conhecidos. Rotacione a credencial alterando as variÃ¡veis e executando `db:seed` novamente.

Os diagnÃ³sticos usam `APP_VERSION`, `SOURCE_COMMIT` e `BUILD_TIMESTAMP`, definidos durante o build.

## Catálogo e pedidos públicos

```http
GET  /api/v1/restaurants/forno-e-massa
GET  /api/v1/restaurants/forno-e-massa/categories
GET  /api/v1/restaurants/forno-e-massa/products
GET  /api/v1/restaurants/forno-e-massa/products?category_id=1
POST /api/v1/restaurants/forno-e-massa/orders
GET  /api/v1/restaurants/forno-e-massa/orders/track?query=%23123
```

O catálogo público retorna somente dados do slug informado e não inclui produtos indisponíveis. Identificadores de outro restaurante resultam em `404`.

Exemplo de pedido:

```json
{
  "order": {
    "customer_name": "Ana",
    "customer_phone": "11999999999",
    "order_type": "delivery",
    "delivery_address": "Rua A, 1",
    "payment_method": "pix",
    "items": [{ "product_id": 1, "quantity": 2, "addon_ids": [3, 4] }]
  }
}
```

Para `order_type: dine_in`, informe `table_number` no lugar de `delivery_address`. O cliente nunca envia `unit_price` ou `total`: a API usa o preço persistido, calcula o total e rejeita produtos indisponíveis ou pertencentes a outro restaurante. Pedido e itens são gravados de forma atômica.

### Horário de funcionamento

Novos pedidos são aceitos somente durante um intervalo habilitado em `menu_information.hours`, avaliado no fuso IANA configurado pelo restaurante. A abertura pertence ao intervalo e o instante exato do fechamento já é considerado fechado. Intervalos que atravessam a meia-noite são suportados; quando nenhum horário está configurado ou habilitado, o restaurante permanece fechado para novos pedidos.

O cardápio continua disponível para consulta e pedidos existentes continuam acessíveis pelo acompanhamento. Uma tentativa de criar pedido fora do horário responde `409` sem persistir pedido ou itens:

```json
{
  "error": "restaurant_closed",
  "messages": ["Restaurante fechado. Abre às 18:00."],
  "next_opening": "18:00"
}
```

`next_opening` será `null` quando não houver próxima abertura habilitada na agenda semanal.

### Preços de produtos personalizados

O servidor sempre calcula os preços usando os registros persistidos e ignora valores enviados pelo navegador. Para produtos sem variação, o preço unitário é `produto.price + soma dos adicionais`. Para produtos com variação, `variant.price` representa o preço final absoluto daquela opção e o cálculo é `variant.price + soma dos adicionais`; o preço base não é somado novamente.

No JSON de importação, `addons[].price` é um acréscimo e `variants[].price` é o valor final do produto naquela variação. Exemplo: produto base de R$ 24,90, variação Duplo de R$ 30,90 e Bacon de R$ 4,50 resultam em R$ 35,40 por unidade; duas unidades totalizam R$ 70,80.

### Acompanhamento público de pedido

`GET /api/v1/restaurants/:restaurant_slug/orders/track?query=<valor>` aceita o número do pedido (com `#` opcional) ou o telefone usado no checkout. A busca é sempre limitada ao restaurante da URL. Por telefone, retorna o pedido em andamento mais recente; se não houver um em andamento, retorna o mais recente.

O retorno contém somente `id`, `status`, `order_type` e `created_at`. Nome, telefone, endereço, pagamento, itens, observações e valores nunca são enviados. Pedidos ausentes ou de outro restaurante respondem `404` com a mesma mensagem. Entrada inválida responde `422`; o limite de 12 consultas por minuto para cada IP/restaurante responde `429`.

## Administração

Envie o token retornado pela sessão:

```http
Authorization: Bearer <token>
```

As operações administrativas usam as mesmas rotas com slug e exigem que o token pertença ao restaurante da URL. Um slug de outro tenant responde `404`; token ausente ou inválido responde `401`; papel/permissão insuficiente responde `403`.

```text
GET|POST|PATCH|DELETE /api/v1/restaurants/:restaurant_slug/categories
GET|POST|PATCH|DELETE /api/v1/restaurants/:restaurant_slug/products
GET|POST|PATCH        /api/v1/restaurants/:restaurant_slug/orders
GET|POST|PATCH|DELETE /api/v1/restaurants/:restaurant_slug/users
PATCH                 /api/v1/restaurants/:restaurant_slug
```

Para listar também produtos indisponíveis no painel, use `GET .../products?admin=true` com permissão `products:write`.

Erros esperados usam JSON com código estável e mensagens:

```json
{ "error": "validation_error", "messages": ["Customer name is too short"] }
```

## Migração das rotas legadas

Rotas como `/api/v1/products`, `/api/v1/categories`, `/api/v1/orders` e `/api/v1/users` foram removidas. Acrescente `/restaurants/:restaurant_slug` antes do recurso. Não há redirecionamento automático, inclusive para operações de escrita.

## Testes

```bash
docker compose -f docker-compose.dev.yml run --rm -e RAILS_ENV=test -e TEST_DATABASE_URL=postgres://postgres:postgres@db:5432/pedeai_test --entrypoint bundle api exec rails test
```
