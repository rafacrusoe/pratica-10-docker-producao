import os

import psycopg2
from flask import Flask, jsonify, render_template_string


app = Flask(__name__)


def connection():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "db"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("POSTGRES_DB"),
        user=os.getenv("POSTGRES_USER"),
        password=os.getenv("POSTGRES_PASSWORD"),
    )


def fetch_all(query, params=None):
    with connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, params or ())
            columns = [item.name for item in cur.description]
            return [dict(zip(columns, row)) for row in cur.fetchall()]


@app.get("/health")
def health():
    with connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT 1")
    return jsonify(status="ok", servico="consultas", banco="conectado")


@app.get("/transactions")
def transactions():
    return jsonify(fetch_all("SELECT * FROM transacoes ORDER BY id DESC LIMIT 50"))


@app.get("/balances")
def balances():
    return jsonify(fetch_all("""
        SELECT conta,
               SUM(CASE WHEN tipo = 'deposito' THEN valor ELSE -valor END)::float AS saldo
        FROM transacoes GROUP BY conta ORDER BY conta
    """))


@app.get("/")
def index():
    transactions_data = fetch_all("SELECT * FROM transacoes ORDER BY id DESC LIMIT 20")
    balances_data = fetch_all("""
        SELECT conta,
               SUM(CASE WHEN tipo = 'deposito' THEN valor ELSE -valor END)::float AS saldo
        FROM transacoes GROUP BY conta ORDER BY conta
    """)
    return render_template_string("""<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">
    <title>Banco App - Consultas</title><style>
    body{font-family:Arial,sans-serif;background:#f5f5f5;margin:0;color:#111}header{background:#111;color:white;padding:24px 48px}
    main{max-width:1000px;margin:32px auto;background:#fff;padding:30px;border-radius:10px;box-shadow:0 2px 12px #bbb}
    .status{display:inline-block;background:#daf5df;border:1px solid #3a8d47;padding:10px 16px;border-radius:7px}
    .cards{display:flex;gap:16px;margin:24px 0}.card{flex:1;background:#eee;padding:18px;border-radius:8px}
    table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:12px;border-bottom:1px solid #ddd}th{background:#eee}</style></head><body>
    <header><h1>Banco App</h1><p>Microsservico de consultas em Python</p></header><main>
    <div class="status">Servico ativo e conectado ao PostgreSQL</div><h2>Saldos consolidados</h2><div class="cards">
    {% for item in balances %}<div class="card"><strong>{{ item.conta }}</strong><br>R$ {{ "%.2f"|format(item.saldo) }}</div>{% endfor %}</div>
    <h2>Historico de transacoes</h2><table><thead><tr><th>ID</th><th>Conta</th><th>Tipo</th><th>Valor</th></tr></thead><tbody>
    {% for item in transactions %}<tr><td>{{ item.id }}</td><td>{{ item.conta }}</td><td>{{ item.tipo }}</td><td>R$ {{ item.valor }}</td></tr>{% endfor %}
    </tbody></table></main></body></html>""", transactions=transactions_data, balances=balances_data)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

