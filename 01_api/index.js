const express = require("express");
const mysql = require("mysql2/promise");
const cors = require("cors");
require("dotenv").config({ path: ".env.local" });

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cors());

const pool = mysql.createPool({
  host: process.env.DB_HOST || "localhost",
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "",
  database: process.env.DB_NAME || "test",
  port: Number(process.env.DB_PORT || 3306),
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

app.get("/health", async (req, res) => {
  try {
    const [rows] = await pool.query("SELECT 1 AS ok");
    res.json({ status: "ok", db: rows[0].ok === 1 });
  } catch (e) {
    console.error(e);
    res.status(500).json({ status: "error", message: e.message });
  }
});

app.get("/attractions", async (req, res) => {
  try {
    const [rows] = await pool.query("SELECT * FROM attraction");
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

const port = Number(process.env.PORT || 3001);
if (require.main === module) {
  app.listen(port, () =>
    console.log(`API listening on http://localhost:${port}`),
  );
}

module.exports = { app, pool };

