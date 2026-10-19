require("dotenv").config();

const path = require("path");
const express = require("express");
const connectDB = require("./config/db");

const authRoutes = require("./routes/auth");
const apiRoutes = require("./routes/api");
const assetsRoutes = require("./routes/assets");
const staffRoutes = require("./routes/staff");
const lenderRoutes = require("./routes/lender");
const borrowerRoutes = require("./routes/borrower");

const app = express();

// CORS: allow the Flutter web app (Cloudflare Pages) to call this API from another origin
app.use((req, res, next) => {
  res.setHeader("Access-Control-Allow-Origin", process.env.CORS_ORIGIN || "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
  if (req.method === "OPTIONS") return res.sendStatus(204);
  next();
});

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use("/public", express.static(path.join(__dirname, "public")));

connectDB().catch((error) => {
  console.error("Database connection error:", error);
});

app.use("/", authRoutes); // POST /login, POST /register
app.use("/api", apiRoutes); // /api/... (student + shared history/notification endpoints)
app.use("/", assetsRoutes); // GET /assets
app.use("/staff", staffRoutes);
app.use("/lender", lenderRoutes);
app.use("/borrower", borrowerRoutes);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`server is running on port ${PORT}`);
});
