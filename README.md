# Prática 10 — Docker em produção

Aplicação bancária end-to-end contêinerizada com PostgreSQL, um microsserviço de transações em Node.js e um microsserviço de consultas em Python.

## Componentes

- `db`: PostgreSQL 13 com volume persistente e política `unless-stopped`;
- `transaction-service`: API REST em Node.js na porta 3000;
- `query-service`: API REST em Python na porta 5000;
- `banco-network`: rede bridge privada entre os três serviços.

Cada serviço possui limite de 512 MB de memória e 0,5 CPU. Os serviços de aplicação usam a política de reinicialização `always`.

## Execução

```bash
cp .env.example .env
npm install
npx playwright install chromium
chmod +x scripts/run-pratica.sh
./scripts/run-pratica.sh
```

O script constrói as imagens, inicia os contêineres, aguarda os healthchecks, registra transações, consulta os saldos, verifica o consumo com `docker stats` e produz as evidências reais em `evidencias/`.

## Endpoints

- `http://localhost:3000/health`
- `http://localhost:3000/transactions`
- `http://localhost:5000/health`
- `http://localhost:5000/transactions`
- `http://localhost:5000/balances`

