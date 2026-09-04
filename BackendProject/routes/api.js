const express = require("express");

const User = require("../models/User");
const Asset = require("../models/Asset");
const BorrowRequest = require("../models/BorrowRequest");
const { nextSequence } = require("../models/Counter");
const { requireAuth } = require("../middleware/auth");
const { makeLookup, serializeHistoryItem } = require("../utils/serialize");

const router = express.Router();

// A student is blocked from starting a new borrow while they have one
// in flight: still pending lender approval, or approved and not yet
// returned. Mirrors _hasActiveRequest()/_activeStatusItem in student.dart.
function isBlockingRequest(request) {
  if (request.request_status === "Pending") return true;
  if (request.request_status === "Approved" && request.return_status === "Not Returned") return true;
  return false;
}

// ---------- GET /api/user/:id ----------
router.get("/user/:id", async (req, res) => {
  const user = await User.findOne({ user_id: Number(req.params.id) });
  if (!user) return res.status(404).json({ message: "User not found" });
  res.json({ username: user.username });
});

// ---------- GET /api/student/status/:borrowerId ----------
router.get("/student/status/:borrowerId", async (req, res) => {
  const borrowerId = Number(req.params.borrowerId);

  const latest = await BorrowRequest.findOne({
    borrower_id: borrowerId,
    return_status: { $ne: "Returned" },
  }).sort({ createdAt: -1 });

  if (!latest) return res.json(null);

  const asset = await Asset.findOne({ asset_id: latest.asset_id });

  let asset_status;
  if (latest.request_status === "Pending") asset_status = "Pending";
  else if (latest.request_status === "Rejected") asset_status = "Rejected";
  else asset_status = "Borrowed"; // Approved

  res.json({
    request_id: latest.request_id,
    request_date: latest.createdAt,
    asset_name: asset ? asset.name : "Unknown Item",
    asset_status,
    return_status: latest.return_status,
    can_borrow_today: isBlockingRequest(latest) ? 0 : 1,
  });
});

// ---------- GET /api/student/asset?borrower_id= ----------
router.get("/student/asset", async (req, res) => {
  const assets = await Asset.find({}).sort({ asset_id: 1 });

  // Attach the return_status of whichever request currently has the asset
  // Pending/Borrowed, so the app can show "Request Return" (purple) etc.
  const activeRequests = await BorrowRequest.find({
    request_status: { $in: ["Pending", "Approved"] },
    return_status: { $ne: "Returned" },
  });
  const byAsset = new Map(activeRequests.map((r) => [r.asset_id, r]));

  const result = assets.map((a) => {
    const active = byAsset.get(a.asset_id);
    return {
      asset_id: a.asset_id,
      asset_name: a.name,
      asset_status: a.status,
      image: a.image,
      return_status: active ? active.return_status : "Not Returned",
    };
  });

  res.json({ success: true, assets: result });
});

// ---------- POST /api/student/borrow ----------
router.post("/student/borrow", async (req, res) => {
  const { borrower_id, asset_id, borrow_date, return_date } = req.body || {};
  const borrowerId = Number(borrower_id);
  const assetId = Number(asset_id);

  if (!borrowerId || !assetId || !borrow_date || !return_date) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  const asset = await Asset.findOne({ asset_id: assetId });
  if (!asset) return res.status(404).json({ message: "Asset not found" });
  if (asset.status !== "Available") {
    return res.status(400).json({ message: "Asset is not available" });
  }

  const existing = await BorrowRequest.find({ borrower_id: borrowerId });
  if (existing.some(isBlockingRequest)) {
    return res.status(400).json({ message: "You already have an active request" });
  }

  const request_id = await nextSequence("request_id");
  await BorrowRequest.create({
    request_id,
    borrower_id: borrowerId,
    asset_id: assetId,
    borrow_date: new Date(borrow_date),
    return_date: new Date(return_date),
  });

  asset.status = "Pending";
  await asset.save();

  res.status(200).json({ message: "Borrow request sent", request_id });
});

// ---------- PUT /api/student/returnAsset/:requestId ----------
// Student-initiated "I'm returning this" — only flags the request for staff
// to confirm; staff/returnAsset/:id is what actually completes the return.
router.put("/student/returnAsset/:requestId", async (req, res) => {
  const requestId = Number(req.params.requestId);
  const request = await BorrowRequest.findOne({ request_id: requestId });
  if (!request) return res.status(404).json({ message: "Request not found" });

  if (request.request_status !== "Approved" || request.return_status !== "Not Returned") {
    return res.status(400).json({ message: "This request cannot be returned right now" });
  }

  request.return_status = "Requested Return";
  request.staff_seen = false;
  await request.save();

  res.status(200).json({ message: "Return requested" });
});

// ---------- POST /api/notifyReturn ----------
// Fire-and-forget ping from the student app after requesting a return; the
// staff badge count is derived from staff_seen so there's nothing else to do.
router.post("/notifyReturn", (req, res) => {
  res.status(200).json({ message: "ok" });
});

// ---------- GET /api/student/notificationCount/:borrowerId ----------
router.get("/student/notificationCount/:borrowerId", requireAuth, async (req, res) => {
  const borrowerId = Number(req.params.borrowerId);
  const count = await BorrowRequest.countDocuments({ borrower_id: borrowerId, student_seen: false });
  res.json({ success: true, count });
});

// ---------- DELETE /api/student/clearNotifications/:borrowerId ----------
router.delete("/student/clearNotifications/:borrowerId", requireAuth, async (req, res) => {
  const borrowerId = Number(req.params.borrowerId);
  await BorrowRequest.updateMany(
    { borrower_id: borrowerId, student_seen: false },
    { $set: { student_seen: true } }
  );
  res.status(200).json({ success: true });
});

// ---------- GET /api/student/history/:userId ----------
router.get("/student/history/:userId", async (req, res) => {
  const userId = Number(req.params.userId);
  const requests = await BorrowRequest.find({ borrower_id: userId }).sort({ createdAt: -1 });
  const lookup = makeLookup();
  res.json(await Promise.all(requests.map((r) => serializeHistoryItem(r, lookup))));
});

// ---------- GET /api/lender/history/:userId ----------
router.get("/lender/history/:userId", async (req, res) => {
  const userId = Number(req.params.userId);
  const requests = await BorrowRequest.find({ lender_id: userId }).sort({ createdAt: -1 });
  const lookup = makeLookup();
  res.json(await Promise.all(requests.map((r) => serializeHistoryItem(r, lookup))));
});

// ---------- GET /api/staff/history ----------
router.get("/staff/history", async (req, res) => {
  const requests = await BorrowRequest.find({}).sort({ createdAt: -1 });
  const lookup = makeLookup();
  res.json(await Promise.all(requests.map((r) => serializeHistoryItem(r, lookup))));
});

// ---------- GET /api/returnCount ----------
router.get("/returnCount", requireAuth, async (req, res) => {
  const count = await BorrowRequest.countDocuments({
    return_status: "Requested Return",
    staff_seen: false,
  });
  res.json({ count });
});

// ---------- DELETE /api/clearReturnNotifications ----------
router.delete("/clearReturnNotifications", requireAuth, async (req, res) => {
  await BorrowRequest.updateMany(
    { return_status: "Requested Return", staff_seen: false },
    { $set: { staff_seen: true } }
  );
  res.status(200).json({ message: "Cleared" });
});

module.exports = router;
