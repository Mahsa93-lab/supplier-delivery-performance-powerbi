# Report design – Supplier & Delivery Performance

Canvas 16:9 (1280 × 720). Theme: one dark blue for primary values (#1F4E79), one orange for alerts (#C0632B), grey for context. Font Segoe UI.
**Report-level filter:** `dim_date[Is Analysis Period] = True`. Every page gets a header (title + last refresh), a Year/Quarter slicer and a navigation bar (buttons).

---

## Page 1 – Executive Overview
Question: *How are we doing overall, and is it getting better?*

| # | Visual | Fields | Notes |
|---|---|---|---|
| 1 | 5 × Card (new card visual) | Revenue (BRL), Orders, Customer OTD %, Supplier OTD %, Complaint Rate % | reference label: Revenue YoY % |
| 2 | Line chart | X: dim_date[Year-Month]; Y: Customer OTD %, Supplier OTD % | constant line 0.92 (target) |
| 3 | Clustered column | X: dim_date[Year-Month]; Y: Revenue (BRL) | tooltip: Orders |
| 4 | Filled map or bar chart | dim_customer[state]; Customer OTD % | sort ascending – worst states first |
| 5 | Text box (smart narrative) | "Late deliveries get a 1–2 star review 6.7× more often" | write the key insight in one sentence |

## Page 2 – Supplier Scorecard
Question: *Which suppliers need attention first?*

| # | Visual | Fields | Notes |
|---|---|---|---|
| 1 | Table | dim_seller[seller_id], dim_seller[state], Order Items, Revenue (BRL), ABC Class, Supplier OTD %, Avg Seller Processing (days), Supplier Complaint Rate %, OTD Status | visual filter: Is Relevant Supplier = 1; icons on OTD Status (1 green, 2 amber, 3 red); data bars on Revenue |
| 2 | Donut or 100 % bar | ABC Class; Active Suppliers / Revenue (BRL) | shows the 18 % → 80 % effect |
| 3 | Scatter chart | X: Supplier OTD %; Y: Supplier Complaint Rate %; size: Revenue (BRL); details: seller_id | quadrant lines at 0.90 / 0.12 → top-left = critical |
| 4 | Slicer | ABC Class, OTD Status | |
| 5 | Drill-through page "Supplier Detail" | drill-through field: dim_seller[seller_id] | monthly Supplier OTD, items by category, late handovers |

## Page 3 – Delivery & Lead Time
Question: *Where and why are deliveries late?*

| # | Visual | Fields | Notes |
|---|---|---|---|
| 1 | Pareto (line + clustered column) | X: dim_seller[seller_id] (Top 50 by Late Handovers); columns: Late Handovers; line: Cumulative Late Handover Share % | secondary axis 0–100 %; constant line 0.8 |
| 2 | Decomposition tree | Analyse: Late Orders; explain by: dim_customer[state], dim_date[Year-Month] | |
| 3 | Line chart | X: dim_date[Year-Month]; Y: Avg Lead Time (days), Avg Days Late (late orders) | annotate Nov 2017 (Black Friday) |
| 4 | Clustered bar | Complaint Rate % (late) vs. Complaint Rate % (on time) | the most important chart of the report |
| 5 | Tooltip page | Customer OTD %, Orders, Avg Lead Time | assign to visual 2 and 3 |

## Page 4 – Data Quality
Question: *Can we trust these numbers?*

| # | Visual | Fields | Notes |
|---|---|---|---|
| 1 | Card | DQ Score %, DQ Checks Failed | target ≥ 99 % |
| 2 | Table | dq_checks[check_id], dimension, table_name, check_name, failed_rows, total_rows, DQ Failure Rate % | conditional formatting: failed_rows > 0 → orange |
| 3 | Clustered bar | dq_checks[dimension]; DQ Failed Rows | completeness / validity / consistency / uniqueness / integrity |
| 4 | Text box | "How we handle it": e.g. carrier-before-approval rows are excluded from processing time | link to KPI-Definitionen |

---

## Finishing touches (they make the difference)
- Bookmarks: "Only red A-suppliers" on page 2
- Row-level security demo: role `Region SP` with filter `dim_customer[state] = "SP"` (Modeling → Manage roles), show "View as" in a screenshot
- Performance Analyzer: all visuals < 500 ms (screenshot in README)
- Field descriptions on every measure (Model view → Properties → Description) – copy from KPI-Definitionen.md
- Hide technical columns (keys, flags) from report view; group measures in display folders: Customer, Supplier, Time, DQ
- Export: File → Export → PDF → `powerbi/supplier_performance.pdf`
