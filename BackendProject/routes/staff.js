const express = require("express");

const Asset = require("../models/Asset");
const BorrowRequest = require("../models/BorrowRequest");
const { nextSequence } = require("../models/Counter");
const { requireAuth } = require("../middleware/auth");
const upload = require("../middleware/upload");

const router = express.Router();

// ---------- POST /staff/addAsset ----------
router.post("/addAsset", requireAuth, upload.single("image"), async (req, res) => {
  try {
    const { name, description } = req.body || {};
    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: "Name is required" });
    }

    const asset_id = await nextSequence("asset_id");
    const image = req.file ? `/public/image/${req.file.filename}` : null;

    await Asset.create({ asset_id, name: name.trim(), description: description || "", image });

    res.status(200).json({ success: true, message: "Asset added successfully" });
  } catch (err) {
    console.error("addAsset error:", err);
    res.status(500).json({ success: false, message: "Server error" });
  }
});

// ---------- PUT /staff/editAsset/:id ----------
router.put("/editAsset/:id", requireAuth, upload.single("image"), async (req, res) => {
  try {
    const asset = await Asset.findOne({ asset_id: Number(req.params.id) });
    if (!asset) return res.status(404).json({ success: false, message: "Asset not found" });

    const { name, description } = req.body || {};
    if (name && name.trim()) asset.name = name.trim();
    if (description) asset.description = description;
    if (req.file) asset.image = `/public/image/${req.file.filename}`;

    await asset.save();
    res.status(200).json({ success: true, message: "Asset updated successfully" });
  } catch (err) {
    console.error("editAsset error:", err);
    res.status(500).json({ success: false, message: "Server error" });
  }
});

// ---------- PUT /staff/editAsset/:id/enable | /staff/editAsset/:id/disable ----------
router.put("/editAsset/:id/:action", requireAuth, async (req, res) => {
  const { id, action } = req.params;
  if (!["enable", "disable"].includes(action)) {
    return res.status(400).json({ success: false, message: "Invalid action" });
  }

  const asset = await Asset.findOne({ asset_id: Number(id) });
  if (!asset) return res.status(404).json({ success: false, message: "Asset not found" });

  if (action === "disable") {
    if (asset.status === "Borrowed") {
      return res.status(400).json({ success: false, message: "This asset is currently borrowed" });
    }
    asset.status = "Disabled";
  } else {
    asset.status = "Available";
  }

  await asset.save();
  res.status(200).json({ success: true, message: `Asset ${action}d successfully` });
});

// ---------- DELETE /staff/deleteAsset/:id ----------
router.delete("/deleteAsset/:id", requireAuth, async (req, res) => {
  await Asset.deleteOne({ asset_id: Number(req.params.id) });
  res.status(200).json({ success: true, message: "Asset deleted successfully" });
});

// ---------- GET /staff/dashboard/:staffId ----------
router.get("/dashboard/:staffId", requireAuth, async (req, res) => {
  const [total_assets, available_assets, borrowed_assets, pending_requests] = await Promise.all([
    Asset.countDocuments({}),
    Asset.countDocuments({ status: "Available" }),
    Asset.countDocuments({ status: "Borrowed" }),
    BorrowRequest.countDocuments({ request_status: "Pending" }),
  ]);

  res.json({
    success: true,
    data: { total_assets, available_assets, borrowed_assets, pending_requests },
  });
});

// ---------- GET /staff/request/:staffId ----------
// Requests the student has asked to return, awaiting staff confirmation.
router.get("/request/:staffId", requireAuth, async (req, res) => {
  const requests = await BorrowRequest.find({ return_status: "Requested Return" }).sort({
    createdAt: -1,
  });

  const result = await Promise.all(
    requests.map(async (r) => {
      const asset = await Asset.findOne({ asset_id: r.asset_id });
      return {
        id: r.request_id,
        name: asset ? asset.name : "Unknown Item",
        borrowDate: r.borrow_date,
        returnDate: r.return_date,
        returnStatus: r.return_status,
      };
    })
  );

  res.json({ requests: result });
});

// ---------- PUT /staff/returnAsset/:requestId ----------
router.put("/returnAsset/:requestId", requireAuth, async (req, res) => {
  const requestId = Number(req.params.requestId);
  const { staff_id } = req.body || {};

  const request = await BorrowRequest.findOne({ request_id: requestId });
  if (!request) return res.status(404).json({ message: "Request not found" });

  request.return_status = "Returned";
  request.staff_id = Number(staff_id) || request.staff_id;
  request.returned_at = new Date();
  request.staff_seen = true;
  await request.save();

  const asset = await Asset.findOne({ asset_id: request.asset_id });
  if (asset) {
    asset.status = "Available";
    await asset.save();
  }

  res.status(200).json({ message: "Asset returned successfully" });
});

module.exports = router;
