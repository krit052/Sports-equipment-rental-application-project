const express = require("express");

const Asset = require("../models/Asset");
const BorrowRequest = require("../models/BorrowRequest");

const router = express.Router();

// ---------- GET /borrower/status/:borrowerId ----------
router.get("/status/:borrowerId", async (req, res) => {
  const borrowerId = Number(req.params.borrowerId);
  const requests = await BorrowRequest.find({ borrower_id: borrowerId }).sort({ createdAt: -1 });

  const result = await Promise.all(
    requests.map(async (r) => {
      const asset = await Asset.findOne({ asset_id: r.asset_id });
      return {
        request_id: r.request_id,
        asset_name: asset ? asset.name : "Unknown Item",
        image: asset ? asset.image : null,
        borrow_date: r.borrow_date,
        return_date: r.return_date,
        return_status: r.return_status,
      };
    })
  );

  res.json({ success: true, requests: result });
});

// ---------- PUT /borrower/return/:requestId ----------
router.put("/return/:requestId", async (req, res) => {
  const requestId = Number(req.params.requestId);
  const request = await BorrowRequest.findOne({ request_id: requestId });
  if (!request) return res.status(404).json({ message: "Request not found" });

  request.return_status = "Returned";
  request.returned_at = new Date();
  await request.save();

  const asset = await Asset.findOne({ asset_id: request.asset_id });
  if (asset) {
    asset.status = "Available";
    await asset.save();
  }

  res.status(200).json({ message: "Item returned successfully" });
});

module.exports = router;
