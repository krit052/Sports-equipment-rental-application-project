const express = require("express");

const Asset = require("../models/Asset");
const User = require("../models/User");
const BorrowRequest = require("../models/BorrowRequest");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

// ---------- GET /lender/asset-stats ----------
router.get("/asset-stats", requireAuth, async (req, res) => {
  const [total, available, pending, borrowed, disabled] = await Promise.all([
    Asset.countDocuments({}),
    Asset.countDocuments({ status: "Available" }),
    Asset.countDocuments({ status: "Pending" }),
    Asset.countDocuments({ status: "Borrowed" }),
    Asset.countDocuments({ status: "Disabled" }),
  ]);

  res.json({ success: true, stats: { total, available, pending, borrowed, disabled } });
});

// ---------- GET /lender/pending-requests ----------
router.get("/pending-requests", requireAuth, async (req, res) => {
  const requests = await BorrowRequest.find({ request_status: "Pending" }).sort({ createdAt: -1 });

  const result = await Promise.all(
    requests.map(async (r) => {
      const [asset, borrower] = await Promise.all([
        Asset.findOne({ asset_id: r.asset_id }),
        User.findOne({ user_id: r.borrower_id }),
      ]);
      return {
        request_id: r.request_id,
        asset_name: asset ? asset.name : "Unknown Item",
        asset_image: asset ? asset.image : null,
        borrower_name: borrower ? borrower.username : "Unknown",
        borrow_date: r.borrow_date,
      };
    })
  );

  res.json({ success: true, pendingRequests: result });
});

// ---------- PUT /lender/borrowingRequest/:requestId/:action ----------
router.put("/borrowingRequest/:requestId/:action", requireAuth, async (req, res) => {
  const { requestId, action } = req.params;
  if (!["approve", "reject"].includes(action)) {
    return res.status(400).json({ message: "Invalid action" });
  }

  const request = await BorrowRequest.findOne({ request_id: Number(requestId) });
  if (!request) return res.status(404).json({ message: "Request not found" });
  if (request.request_status !== "Pending") {
    return res.status(400).json({ message: "This request has already been processed" });
  }

  const { lender_id, reason } = req.body || {};
  request.lender_id = Number(lender_id) || request.lender_id;
  request.student_seen = false; // notify the student of the decision

  const asset = await Asset.findOne({ asset_id: request.asset_id });

  if (action === "approve") {
    request.request_status = "Approved";
    if (asset) asset.status = "Borrowed";
  } else {
    request.request_status = "Rejected";
    request.reject_reason = reason || null;
    if (asset) asset.status = "Available";
  }

  await request.save();
  if (asset) await asset.save();

  res.status(200).json({ message: "Action successful" });
});

module.exports = router;
