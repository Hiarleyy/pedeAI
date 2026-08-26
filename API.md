# PedeAI API

API Rails para cardapio online com pedidos de delivery e atendimento presencial.

## Executar com Docker

```bash
docker compose up --build
docker compose exec api bundle exec rails db:seed
```

- Swagger UI: http://localhost:3000/docs
- OpenAPI: http://localhost:3000/openapi.yaml
- Health check: http://localhost:3000/up

## Endpoints

`GET/POST /api/v1/categories`, `GET/POST /api/v1/products`, `GET/POST /api/v1/orders` e `PATCH /api/v1/orders/:id`.

Pedidos usam `order_type: delivery` com `delivery_address` ou `order_type: dine_in` com `table_number`. Itens devem informar `product_id` e `quantity`; o total nunca vem do cliente.

## Testes

```bash
docker compose run --rm api bundle exec rails test
```
