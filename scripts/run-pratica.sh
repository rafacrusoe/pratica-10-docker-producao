#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p evidencias
if [[ ! -f .env ]]; then
  cp .env.example .env
fi

cleanup() {
  docker compose down -v --remove-orphans > evidencias/99-compose-down.txt 2>&1 || true
}
trap cleanup EXIT

docker --version | tee evidencias/01-versoes.txt
docker compose version | tee -a evidencias/01-versoes.txt
docker compose config > evidencias/02-compose-config.txt

docker compose build |& tee evidencias/03-compose-build.txt
docker compose up -d |& tee evidencias/04-compose-up.txt

for endpoint in http://127.0.0.1:3000/health http://127.0.0.1:5000/health; do
  for _ in $(seq 1 60); do
    if curl -fsS "$endpoint" >/dev/null; then
      break
    fi
    sleep 2
  done
  curl -fsS "$endpoint" | tee -a evidencias/05-healthchecks.json
  printf '\n' | tee -a evidencias/05-healthchecks.json
done

curl -fsS -X POST http://127.0.0.1:3000/transactions \
  -H 'Content-Type: application/json' \
  -d '{"conta":"conta-001","tipo":"deposito","valor":1500.00}' | tee evidencias/06-transacao-1.json
curl -fsS -X POST http://127.0.0.1:3000/transactions \
  -H 'Content-Type: application/json' \
  -d '{"conta":"conta-001","tipo":"saque","valor":275.50}' | tee evidencias/07-transacao-2.json
curl -fsS -X POST http://127.0.0.1:3000/transactions \
  -H 'Content-Type: application/json' \
  -d '{"conta":"conta-002","tipo":"deposito","valor":800.00}' | tee evidencias/08-transacao-3.json

curl -fsS http://127.0.0.1:5000/transactions | tee evidencias/09-consulta-transacoes.json
curl -fsS http://127.0.0.1:5000/balances | tee evidencias/10-consulta-saldos.json

docker compose ps | tee evidencias/11-compose-ps.txt
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}' | tee evidencias/12-docker-stats.txt
docker inspect pratica-10-docker-producao-db-1 pratica-10-docker-producao-transaction-service-1 pratica-10-docker-producao-query-service-1 \
  --format '{{.Name}} restart={{.HostConfig.RestartPolicy.Name}} memory={{.HostConfig.Memory}} nano_cpus={{.HostConfig.NanoCpus}}' \
  | tee evidencias/13-limites-restart.txt
docker network inspect pratica-10-docker-producao_banco-network \
  --format '{{range .Containers}}{{.Name}} {{end}}' | tee evidencias/14-rede.txt

stats_html="$(sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' evidencias/12-docker-stats.txt)"
ps_html="$(sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' evidencias/11-compose-ps.txt)"
limits_html="$(sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' evidencias/13-limites-restart.txt)"

{
  printf '%s\n' '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>Docker em producao</title>'
  printf '%s\n' '<style>body{font-family:Arial,sans-serif;background:#f3f3f3;margin:0;color:#111}header{background:#111;color:#fff;padding:24px 48px}main{max-width:1180px;margin:28px auto;background:#fff;padding:28px;border-radius:10px;box-shadow:0 2px 12px #bbb}section{margin:24px 0}pre{background:#171717;color:#f5f5f5;padding:20px;border-radius:8px;white-space:pre-wrap;font-size:15px;line-height:1.5}.ok{display:inline-block;background:#daf5df;border:1px solid #3a8d47;padding:10px 16px;border-radius:7px}</style></head><body>'
  printf '%s\n' '<header><h1>Pratica 10 - Docker em producao</h1><p>Validacao dos servicos, recursos e politicas de recuperacao</p></header><main><div class="ok">Todos os contêineres estão ativos e saudáveis</div>'
  printf '<section><h2>Status do Docker Compose</h2><pre>%s</pre></section>\n' "$ps_html"
  printf '<section><h2>Uso de CPU e memoria</h2><pre>%s</pre></section>\n' "$stats_html"
  printf '<section><h2>Limites e politicas de restart</h2><pre>%s</pre></section>\n' "$limits_html"
  printf '%s\n' '</main></body></html>'
} > evidencias/03-recursos.html

node scripts/capturar-evidencias.js
file evidencias/*.png | tee evidencias/15-validacao-imagens.txt

