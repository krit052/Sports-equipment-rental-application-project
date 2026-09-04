const mongoose = require("mongoose");

// Denormalized (numeric FK) on purpose: borrower_id/asset_id/lender_id/staff_id
// are plain numbers, joined at read time via User/Asset lookups. Keeps ids
// consistent with the numeric ids used everywhere else in the API contract.
const borrowRequestSchema = new mongoose.Schema({
  request_id: { type: Number, required: true, unique: true },
  borrower_id: { type: Number, required: true },
  asset_id: { type: Number, required: true },
  lender_id: { type: Number, default: null },
  staff_id: { type: Number, default: null },

  borrow_date: { type: Date },
  return_date: { type: Date },

  request_status: {
    type: String,
    enum: ["Pending", "Approved", "Rejected"],
    default: "Pending",
  },
  return_status: {
    type: String,
    enum: ["Not Returned", "Requested Return", "Returned"],
    default: "Not Returned",
  },
  reject_reason: { type: String, default: null },

  // Notification "seen" flags for the student/staff badge counters.
  student_seen: { type: Boolean, default: true },
  staff_seen: { type: Boolean, default: true },

  createdAt: { type: Date, default: Date.now },
  returned_at: { type: Date, default: null },
});

module.exports = mongoose.model("BorrowRequest", borrowRequestSchema);
