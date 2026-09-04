const express = require("express");
const Asset = require("../models/Asset");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

// ---------- GET /assets ----------
router.get("/assets", requireAuth, async (req, res) => {
  const assets = await Asset.find({}).sort({ asset_id: 1 });
  res.json({
    assets: assets.map((a) => ({
      asset_id: a.asset_id,
      asset_name: a.name,
      image: a.image,
      asset_status: a.status,
    })),
  });
});

module.exports = router;
