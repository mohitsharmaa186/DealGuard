const STORAGE_KEY = "dealguard-crm-deals-v1";

const seedDeals = [
  {
    id: "DG-1048",
    account: "Apex Medicals",
    owner: "Riya Sharma",
    region: "West",
    tier: "Strategic",
    stage: "Procurement",
    amount: 124000,
    cost: 79000,
    discount: 18,
    status: "Pending",
    reason: "Competitor offered lower renewal pricing.",
    submittedAt: "2026-05-24T10:15:00",
    activity: [
      "Submitted by Riya Sharma",
      "Routed to Regional Director for strategic account review"
    ]
  },
  {
    id: "DG-1049",
    account: "Nimbus Retail",
    owner: "Kabir Verma",
    region: "North",
    tier: "Growth",
    stage: "Negotiation",
    amount: 86000,
    cost: 54000,
    discount: 12,
    status: "Pending",
    reason: "Bundle discount requested for multi-product deal.",
    submittedAt: "2026-05-25T12:40:00",
    activity: ["Submitted by Kabir Verma", "Routed to Sales Manager"]
  },
  {
    id: "DG-1050",
    account: "Orion Logistics",
    owner: "Neha Iyer",
    region: "South",
    tier: "Standard",
    stage: "Legal Review",
    amount: 152000,
    cost: 116500,
    discount: 28,
    status: "Rejected",
    reason: "One-time discount requested to close this quarter.",
    submittedAt: "2026-05-22T09:05:00",
    activity: [
      "Submitted by Neha Iyer",
      "Routed to Regional Director",
      "Rejected: margin below policy"
    ]
  },
  {
    id: "DG-1051",
    account: "Vertex Fintech",
    owner: "Aman Gupta",
    region: "East",
    tier: "Strategic",
    stage: "Negotiation",
    amount: 232000,
    cost: 131000,
    discount: 8,
    status: "Approved",
    reason: "Partner referral incentive.",
    submittedAt: "2026-05-20T15:15:00",
    activity: ["Submitted by Aman Gupta", "Auto approved under policy"]
  },
  {
    id: "DG-1052",
    account: "Helio Manufacturing",
    owner: "Priya Nair",
    region: "Central",
    tier: "Growth",
    stage: "Procurement",
    amount: 98000,
    cost: 69000,
    discount: 33,
    status: "Pending",
    reason: "Customer expects price match for three-year contract.",
    submittedAt: "2026-05-26T16:10:00",
    activity: ["Submitted by Priya Nair", "Routed to Finance Controller"]
  }
];

const elements = {
  dealRows: document.querySelector("#dealRows"),
  selectedDeal: document.querySelector("#selectedDeal"),
  selectedStatus: document.querySelector("#selectedStatus"),
  approvalPath: document.querySelector("#approvalPath"),
  form: document.querySelector("#dealForm"),
  discountInput: document.querySelector("#discountInput"),
  discountOutput: document.querySelector("#discountOutput"),
  pricingPreview: document.querySelector("#pricingPreview"),
  approveDeal: document.querySelector("#approveDeal"),
  rejectDeal: document.querySelector("#rejectDeal"),
  decisionNote: document.querySelector("#decisionNote"),
  roleSelect: document.querySelector("#roleSelect"),
  searchDeals: document.querySelector("#searchDeals"),
  barChart: document.querySelector("#barChart"),
  timeline: document.querySelector("#timeline"),
  exportCsv: document.querySelector("#exportCsv"),
  resetData: document.querySelector("#resetData"),
  toast: document.querySelector("#toast"),
  metrics: {
    pipeline: document.querySelector("#metricPipeline"),
    pipelineSub: document.querySelector("#metricPipelineSub"),
    approved: document.querySelector("#metricApproved"),
    approvedSub: document.querySelector("#metricApprovedSub"),
    exposure: document.querySelector("#metricExposure"),
    exposureSub: document.querySelector("#metricExposureSub"),
    risk: document.querySelector("#metricRisk"),
    riskSub: document.querySelector("#metricRiskSub")
  }
};

const ROLE_HIERARCHY = {
  "Sales Manager": 1,
  "Regional Director": 2,
  "Finance Controller": 3
};

function canRoleDecide(currentRole, requiredRole) {
  const currentRank = ROLE_HIERARCHY[currentRole];
  const requiredRank = ROLE_HIERARCHY[requiredRole];
  if (currentRank == null || requiredRank == null) return false;
  return currentRank >= requiredRank;
}

let deals = loadDeals();
let activeFilter = "All";
let selectedId = findInitialSelectedId();

render();
updatePreview();

document.querySelectorAll(".segment").forEach((button) => {
  button.addEventListener("click", () => {
    activeFilter = button.dataset.filter;
    document.querySelectorAll(".segment").forEach((item) => item.classList.remove("active"));
    button.classList.add("active");
    renderDealRows();
  });
});

elements.searchDeals.addEventListener("input", renderDealRows);
elements.roleSelect.addEventListener("change", renderSelectedDeal);
elements.discountInput.addEventListener("input", updatePreview);
elements.form.addEventListener("input", updatePreview);
elements.approveDeal.addEventListener("click", () => updateDecision("Approved"));
elements.rejectDeal.addEventListener("click", () => updateDecision("Rejected"));
elements.exportCsv.addEventListener("click", exportCsv);
elements.resetData.addEventListener("click", () => {
  deals = structuredClone(seedDeals);
  selectedId = findInitialSelectedId();
  saveDeals();
  render();
  showToast("Demo data has been reset.");
});

elements.form.addEventListener("submit", (event) => {
  event.preventDefault();
  const formData = new FormData(elements.form);
  const amount = toNumber(formData.get("amount"));
  const cost = toNumber(formData.get("cost"));
  const discount = toNumber(formData.get("discount"));
  const tier = formData.get("tier").toString();
  const policy = getPolicy({ amount, cost, discount, tier });
  const status = policy.requiredRole === "Auto Approved" ? "Approved" : "Pending";
  const owner = cleanText(formData.get("owner")) || "Sales Rep";

  const deal = {
    id: createDealId(),
    account: cleanText(formData.get("account")) || "New Account",
    owner,
    region: formData.get("region").toString(),
    tier,
    stage: formData.get("stage").toString(),
    amount,
    cost,
    discount,
    status,
    reason: cleanText(formData.get("reason")) || "Standard commercial request.",
    submittedAt: new Date().toISOString(),
    activity: [
      `Submitted by ${owner}`,
      status === "Approved" ? "Auto approved under policy" : `Routed to ${policy.requiredRole}`
    ]
  };

  deals = [deal, ...deals];
  selectedId = deal.id;
  saveDeals();
  elements.form.reset();
  elements.discountInput.value = "14";
  render();
  updatePreview();
  showToast(`${deal.id} submitted and ${status.toLowerCase()}.`);
});

function loadDeals() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    return saved ? JSON.parse(saved) : structuredClone(seedDeals);
  } catch {
    return structuredClone(seedDeals);
  }
}

function saveDeals() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(deals));
}

function findInitialSelectedId() {
  const pending = deals.find((deal) => deal.status === "Pending");
  return (pending || deals[0] || {}).id;
}

function render() {
  renderMetrics();
  renderDealRows();
  renderSelectedDeal();
  renderChart();
  renderTimeline();
}

function renderMetrics() {
  const pending = deals.filter((deal) => deal.status === "Pending");
  const approved = deals.filter((deal) => deal.status === "Approved");
  const exposure = deals.reduce((sum, deal) => sum + getDiscountValue(deal), 0);
  const risky = deals.filter((deal) => getPolicy(deal).risk === "High");

  elements.metrics.pipeline.textContent = money(pending.reduce((sum, deal) => sum + getNetRevenue(deal), 0));
  elements.metrics.pipelineSub.textContent = `${pending.length} active request${pending.length === 1 ? "" : "s"}`;
  elements.metrics.approved.textContent = money(approved.reduce((sum, deal) => sum + getNetRevenue(deal), 0));
  elements.metrics.approvedSub.textContent = `${approved.length} won-ready deal${approved.length === 1 ? "" : "s"}`;
  elements.metrics.exposure.textContent = money(exposure);
  elements.metrics.exposureSub.textContent = `${averageDiscount()} average discount`;
  elements.metrics.risk.textContent = risky.length.toString();
  elements.metrics.riskSub.textContent = "Deals below policy";
}

function renderDealRows() {
  const query = elements.searchDeals.value.trim().toLowerCase();
  const filtered = deals.filter((deal) => {
    const matchesFilter = activeFilter === "All" || deal.status === activeFilter;
    const haystack = `${deal.account} ${deal.owner} ${deal.region} ${deal.id}`.toLowerCase();
    return matchesFilter && haystack.includes(query);
  });

  if (!filtered.length) {
    elements.dealRows.innerHTML = `<div class="empty-state">No matching deals found.</div>`;
    return;
  }

  elements.dealRows.innerHTML = filtered
    .map((deal) => {
      const policy = getPolicy(deal);
      const isSelected = deal.id === selectedId ? " selected" : "";

      return `
        <div class="deal-row${isSelected}" role="row">
          <div class="deal-main">
            <strong>${escapeHtml(deal.account)}</strong>
            <div class="amount-line">${deal.id} · ${escapeHtml(deal.owner)} · ${money(getNetRevenue(deal))}</div>
          </div>
          <strong>${deal.discount}%</strong>
          <strong>${getMarginPercent(deal)}%</strong>
          <span class="status-pill status-${deal.status}">${deal.status}</span>
          <button class="select-button" type="button" data-select="${deal.id}">Open</button>
        </div>
      `;
    })
    .join("");

  elements.dealRows.querySelectorAll("[data-select]").forEach((button) => {
    button.addEventListener("click", () => {
      selectedId = button.dataset.select;
      renderDealRows();
      renderSelectedDeal();
    });
  });
}

function renderSelectedDeal() {
  const deal = deals.find((item) => item.id === selectedId) || deals[0];

  if (!deal) {
    elements.selectedDeal.innerHTML = `<div class="empty-state">No deal selected.</div>`;
    elements.approvalPath.innerHTML = "";
    return;
  }

  selectedId = deal.id;
  const policy = getPolicy(deal);
  const role = elements.roleSelect.value;
  const canDecide = deal.status === "Pending" && canRoleDecide(role, policy.requiredRole);
  const alreadyClosed = deal.status !== "Pending";
  const roleMismatch = deal.status === "Pending" && !canDecide;

  elements.selectedStatus.textContent = deal.status;
  elements.selectedStatus.className = `status-pill status-${deal.status}`;

  elements.selectedDeal.innerHTML = `
    <div class="selected-title">
      <div>
        <strong>${escapeHtml(deal.account)}</strong>
        <p>${deal.id} · ${escapeHtml(deal.stage)} · ${escapeHtml(deal.region)}</p>
      </div>
      <span class="risk-pill risk-${policy.risk}">${policy.risk} risk</span>
    </div>

    <div class="detail-list">
      <div><span>Net revenue</span><strong>${money(getNetRevenue(deal))}</strong></div>
      <div><span>Discount value</span><strong>${money(getDiscountValue(deal))}</strong></div>
      <div><span>Gross margin</span><strong>${getMarginPercent(deal)}%</strong></div>
      <div><span>Required approver</span><strong>${policy.requiredRole}</strong></div>
      <div><span>Customer tier</span><strong>${escapeHtml(deal.tier)}</strong></div>
      <div><span>Owner</span><strong>${escapeHtml(deal.owner)}</strong></div>
    </div>

    <div class="pricing-preview">
      <div class="preview-row"><span>Reason</span><strong>${escapeHtml(deal.reason)}</strong></div>
      <div class="preview-row"><span>Policy signal</span><strong>${escapeHtml(policy.signal)}</strong></div>
    </div>
  `;

  elements.approvalPath.innerHTML = getApprovalPath(policy.requiredRole)
    .map((step, index) => {
      const current = step === policy.requiredRole ? " current" : "";
      return `
        <div class="path-step${current}">
          <span class="step-index">${index + 1}</span>
          <strong>${step}</strong>
          <span>${step === "Auto Approved" ? "System" : "User"}</span>
        </div>
      `;
    })
    .join("");

  elements.approveDeal.disabled = !canDecide;
  elements.rejectDeal.disabled = !canDecide;

  if (alreadyClosed) {
    elements.decisionNote.placeholder = "This deal already has a final decision.";
  } else if (roleMismatch) {
    elements.decisionNote.placeholder = `${policy.requiredRole} or higher must decide this request.`;
  } else {
    elements.decisionNote.placeholder = "Add business justification or rejection reason";
  }
}

function renderChart() {
  const counts = deals.reduce((map, deal) => {
    const role = getPolicy(deal).requiredRole;
    map[role] = (map[role] || 0) + 1;
    return map;
  }, {});
  const roles = ["Auto Approved", "Sales Manager", "Regional Director", "Finance Controller"];
  const max = Math.max(1, ...Object.values(counts));

  elements.barChart.innerHTML = roles
    .map((role) => {
      const count = counts[role] || 0;
      const width = Math.max(count ? 8 : 0, Math.round((count / max) * 100));
      return `
        <div class="bar-row">
          <strong>${role}</strong>
          <div class="bar-track"><div class="bar-fill" style="--bar-width: ${width}%"></div></div>
          <span>${count}</span>
        </div>
      `;
    })
    .join("");
}

function renderTimeline() {
  const items = deals
    .flatMap((deal) =>
      deal.activity.map((entry, index) => ({
        deal,
        entry,
        sortValue: new Date(deal.submittedAt).getTime() + index
      }))
    )
    .sort((a, b) => b.sortValue - a.sortValue)
    .slice(0, 8);

  elements.timeline.innerHTML = items
    .map(
      ({ deal, entry }) => `
        <div class="timeline-item">
          <span class="timeline-dot"></span>
          <div>
            <p>${escapeHtml(entry)}</p>
            <span>${deal.id} · ${escapeHtml(deal.account)}</span>
          </div>
        </div>
      `
    )
    .join("");
}

function updatePreview() {
  const formData = new FormData(elements.form);
  const amount = toNumber(formData.get("amount")) || 0;
  const cost = toNumber(formData.get("cost")) || 0;
  const discount = toNumber(formData.get("discount")) || 0;
  const tier = formData.get("tier")?.toString() || "Standard";
  const sample = { amount, cost, discount, tier };
  const policy = getPolicy(sample);

  elements.discountOutput.value = `${discount}%`;
  elements.discountOutput.textContent = `${discount}%`;
  elements.pricingPreview.innerHTML = `
    <div class="preview-row"><span>Final customer price</span><strong>${money(getNetRevenue(sample))}</strong></div>
    <div class="preview-row"><span>Discount value</span><strong>${money(getDiscountValue(sample))}</strong></div>
    <div class="preview-row"><span>Gross margin</span><strong>${getMarginPercent(sample)}%</strong></div>
    <div class="preview-row"><span>Approval route</span><strong>${policy.requiredRole}</strong></div>
  `;
}

function updateDecision(status) {
  const deal = deals.find((item) => item.id === selectedId);

  if (!deal) return;

  const policy = getPolicy(deal);
  const role = elements.roleSelect.value;

  if (deal.status !== "Pending" || !canRoleDecide(role, policy.requiredRole)) {
    showToast(`${policy.requiredRole} or higher must decide ${deal.id}.`);
    return;
  }

  const note = elements.decisionNote.value.trim();
  deal.status = status;
  deal.activity = [
    `${status} by ${role}${note ? `: ${note}` : ""}`,
    ...deal.activity
  ];

  elements.decisionNote.value = "";
  saveDeals();
  render();
  showToast(`${deal.id} ${status.toLowerCase()} by ${role}.`);
}

function getPolicy(deal) {
  const margin = getMarginPercent(deal);
  const discount = toNumber(deal.discount);
  const amount = toNumber(deal.amount);
  const tier = deal.tier || "Standard";

  if (margin < 18 || discount >= 31) {
    return {
      requiredRole: "Finance Controller",
      risk: "High",
      signal: margin < 18 ? "Margin is below finance threshold." : "Discount exceeds 30 percent."
    };
  }

  if (discount >= 21 || amount >= 150000 || (tier === "Strategic" && discount > 15)) {
    return {
      requiredRole: "Regional Director",
      risk: margin < 24 || discount >= 25 ? "High" : "Medium",
      signal: tier === "Strategic" && discount > 15 ? "Strategic account needs director review." : "Large deal or high discount."
    };
  }

  if (discount >= 11) {
    return {
      requiredRole: "Sales Manager",
      risk: margin < 26 ? "Medium" : "Low",
      signal: "Standard manager approval required."
    };
  }

  return {
    requiredRole: "Auto Approved",
    risk: margin < 22 ? "Medium" : "Low",
    signal: "Within standard discount policy."
  };
}

function getApprovalPath(role) {
  if (role === "Auto Approved") return ["Auto Approved"];
  if (role === "Sales Manager") return ["Sales Manager"];
  if (role === "Regional Director") return ["Sales Manager", "Regional Director"];
  return ["Sales Manager", "Regional Director", "Finance Controller"];
}

function getNetRevenue(deal) {
  return toNumber(deal.amount) * (1 - toNumber(deal.discount) / 100);
}

function getDiscountValue(deal) {
  return toNumber(deal.amount) * (toNumber(deal.discount) / 100);
}

function getMarginPercent(deal) {
  const revenue = getNetRevenue(deal);
  if (!revenue) return 0;
  return Math.round(((revenue - toNumber(deal.cost)) / revenue) * 100);
}

function averageDiscount() {
  if (!deals.length) return "0%";
  const average = deals.reduce((sum, deal) => sum + toNumber(deal.discount), 0) / deals.length;
  return `${average.toFixed(1)}%`;
}

function createDealId() {
  const nextNumber =
    deals
      .map((deal) => Number.parseInt(deal.id.replace(/\D/g, ""), 10))
      .filter(Boolean)
      .sort((a, b) => b - a)[0] + 1 || 1053;
  return `DG-${nextNumber}`;
}

function exportCsv() {
  const headings = ["Id", "Account", "Owner", "Region", "Tier", "Amount", "Discount", "Margin", "Status", "Approver"];
  const rows = deals.map((deal) => [
    deal.id,
    deal.account,
    deal.owner,
    deal.region,
    deal.tier,
    getNetRevenue(deal),
    `${deal.discount}%`,
    `${getMarginPercent(deal)}%`,
    deal.status,
    getPolicy(deal).requiredRole
  ]);
  const csv = [headings, ...rows]
    .map((row) => row.map((cell) => `"${String(cell).replaceAll('"', '""')}"`).join(","))
    .join("\n");
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = "dealguard-discount-requests.csv";
  anchor.click();
  URL.revokeObjectURL(url);
  showToast("CSV exported.");
}

function cleanText(value) {
  return value.toString().trim().replace(/\s+/g, " ");
}

function money(value) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0
  }).format(value || 0);
}

function toNumber(value) {
  return Number.parseFloat(value) || 0;
}

function escapeHtml(value) {
  return value
    .toString()
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function showToast(message) {
  elements.toast.textContent = message;
  elements.toast.classList.add("visible");
  window.clearTimeout(showToast.timer);
  showToast.timer = window.setTimeout(() => {
    elements.toast.classList.remove("visible");
  }, 2400);
}
