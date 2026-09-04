const User = require("../models/User");
const Asset = require("../models/Asset");

// Small in-request cache so listing endpoints don't refetch the same
// user/asset document once per row.
function makeLookup() {
  const users = new Map();
  const assets = new Map();

  async function getUser(user_id) {
    if (user_id == null) return null;
    if (!users.has(user_id)) {
      users.set(user_id, await User.findOne({ user_id }));
    }
    return users.get(user_id);
  }

  async function getAsset(asset_id) {
    if (asset_id == null) return null;
    if (!assets.has(asset_id)) {
      assets.set(asset_id, await Asset.findOne({ asset_id }));
    }
    return assets.get(asset_id);
  }

  return { getUser, getAsset };
}

// Shared shape used by /api/student/history, /api/lender/history and
// /api/staff/history — matches the fields each Flutter HistoryItem.fromJson expects.
async function serializeHistoryItem(request, lookup = makeLookup()) {
  const [asset, borrower, lender, staff] = await Promise.all([
    lookup.getAsset(request.asset_id),
    lookup.getUser(request.borrower_id),
    lookup.getUser(request.lender_id),
    lookup.getUser(request.staff_id),
  ]);

  return {
    request_id: request.request_id,
    asset_name: asset ? asset.name : "Unknown Item",
    borrow_date: request.borrow_date,
    return_date: request.return_date,
    request_status: request.request_status,
    return_status: request.return_status,
    borrower_name: borrower ? borrower.username : null,
    lender_name: lender ? lender.username : null,
    staff_name: staff ? staff.username : null,
  };
}

module.exports = { makeLookup, serializeHistoryItem };
