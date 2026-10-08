const express = require("express");
const { Pool } = require("pg");

const app = express();
app.use(express.json());

const pool = new Pool({
  host: process.env.DB_HOST || "db",
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.POSTGRES_DB,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
});

async function initializeDatabase() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS transacoes (
      id SERIAL PRIMARY KEY,
      conta VARCHAR(40) NOT NULL,
      tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('deposito', 'saque')),
      valor NUMERIC(12, 2) NOT NULL CHECK (valor > 0),
      criada_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
}

app.get("/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ status: "ok", servico: "transacoes", banco: "conectado" });
  } catch (error) {
    res.status(503).json({ status: "erro", mensagem: error.message });
  }
});

app.post("/transactions", async (req, res) => {
  const { conta, tipo, valor } = req.body;
  if (!conta || !["deposito", "saque"].includes(tipo) || !(Number(valor) > 0)) {
    return res.status(400).json({ erro: "Informe conta, tipo valido e valor positivo" });
  }
  const result = await pool.query(
    "INSERT INTO transacoes (conta, tipo, valor) VALUES ($1, $2, $3) RETURNING *",
    [conta, tipo, Number(valor)]
  );
  return res.status(201).json(result.rows[0]);
});

app.get("/transactions", async (_req, res) => {
  const result = await pool.query("SELECT * FROM transacoes ORDER BY id DESC LIMIT 20");
  res.json(result.rows);
});

app.get("/", async (_req, res) => {
  const result = await pool.query("SELECT * FROM transacoes ORDER BY id DESC LIMIT 8");
  const rows = result.rows.map((item) => `
    <tr><td>${item.id}</td><td>${item.conta}</td><td>${item.tipo}</td><td>R$ ${Number(item.valor).toFixed(2)}</td></tr>
  `).join("");
  res.type("html").send(`<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">
  <title>Banco App - Transacoes</title><style>
  body{font-family:Arial,sans-serif;background:#f5f5f5;margin:0;color:#111}header{background:#111;color:#fff;padding:24px 48px}
  main{max-width:1000px;margin:32px auto;background:#fff;padding:30px;border-radius:10px;box-shadow:0 2px 12px #bbb}
  .status{display:inline-block;background:#daf5df;border:1px solid #3a8d47;padding:10px 16px;border-radius:7px;margin-bottom:22px}
  table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:13px;border-bottom:1px solid #ddd}th{background:#eee}
  code{background:#eee;padding:3px 6px;border-radius:4px}</style></head><body>
  <header><h1>Banco App</h1><p>Microsservico de transacoes em Node.js</p></header><main>
  <div class="status">Servico ativo e conectado ao PostgreSQL</div>
  <h2>Transacoes processadas</h2><table><thead><tr><th>ID</th><th>Conta</th><th>Tipo</th><th>Valor</th></tr></thead><tbody>${rows}</tbody></table>
  <p>Endpoint de saude: <code>/health</code></p></main></body></html>`);
});

initializeDatabase()
  .then(() => app.listen(3000, "0.0.0.0", () => console.log("Servico de transacoes na porta 3000")))
  .catch((error) => {
    console.error("Falha ao preparar o banco", error);
    process.exit(1);
  });

