const { describe, it, beforeEach, afterEach } = require("node:test");
const assert = require("node:assert");
const request = require("supertest");
const { app, pool } = require("../index");

describe("API Unit Tests", () => {
  let originalQuery;

  beforeEach(() => {
    originalQuery = pool.query;
  });

  afterEach(() => {
    pool.query = originalQuery;
  });

  describe("GET /health", () => {
    it("should return status ok and db true when database is healthy", async () => {
      pool.query = async (sql) => {
        if (sql.includes("SELECT 1")) {
          return [[{ ok: 1 }]];
        }
        return [[]];
      };

      const res = await request(app).get("/health");
      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.body.status, "ok");
      assert.strictEqual(res.body.db, true);
    });

    it("should return status 500 with error message when database fails", async () => {
      pool.query = async () => {
        throw new Error("DB Connection Failed");
      };

      const res = await request(app).get("/health");
      assert.strictEqual(res.statusCode, 500);
      assert.strictEqual(res.body.status, "error");
      assert.strictEqual(res.body.message, "DB Connection Failed");
    });
  });

  describe("GET /attractions", () => {
    it("should return attractions list when query succeeds", async () => {
      const mockData = [
        { id: 1, name: "Phi Phi Islands", detail: "Beautiful island" },
        { id: 2, name: "Eiffel Tower", detail: "Famous landmark" },
      ];

      pool.query = async (sql) => {
        if (sql.includes("SELECT * FROM attraction")) {
          return [mockData];
        }
        return [[]];
      };

      const res = await request(app).get("/attractions");
      assert.strictEqual(res.statusCode, 200);
      assert.deepStrictEqual(res.body, mockData);
    });

    it("should return status 500 when query fails", async () => {
      pool.query = async () => {
        throw new Error("Query execution failed");
      };

      const res = await request(app).get("/attractions");
      assert.strictEqual(res.statusCode, 500);
      assert.strictEqual(res.body.error, "Internal Server Error");
    });
  });

  describe("Unknown routes", () => {
    it("should return 404 for unknown route", async () => {
      const res = await request(app).get("/unknown");
      assert.strictEqual(res.statusCode, 404);
    });
  });
});

