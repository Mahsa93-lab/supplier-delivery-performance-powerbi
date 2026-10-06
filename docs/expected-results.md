# Expected results (test reference)

Computed from the original Olist CSVs with the same logic as the SQL scripts. After each step, your numbers in SSMS / Power BI must match these values. Small differences in the last decimal place are fine.

## Step 1 – Staging tables (after `load_olist_to_sqlserver.py`)

| Table | Rows |
|---|---:|
| stg.orders | 99,441 |
| stg.order_items | 112,650 |
| stg.customers | 99,441 |
| stg.sellers | 3,095 |
| stg.products | 32,951 |
| stg.order_reviews | 99,224 |
| stg.order_payments | 103,886 |
| stg.category_translation | 71 |

## Step 2 – Profiling (`02_profiling.sql`)

| Check | Expected |
|---|---:|
| Orders with status `delivered` | 96,478 |
| Status `shipped` / `canceled` / `unavailable` | 1,107 / 625 / 609 |
| Status `invoiced` / `processing` / `created` / `approved` | 314 / 301 / 5 / 2 |
| Duplicates `orders.order_id` | 0 |
| Duplicates `order_reviews.review_id` | 814 |
| Delivered before purchase | 0 |
| Handed to carrier before approval | 1,359 |
| Items without seller / without product | 0 / 0 |

## Step 3 – Star schema & data quality (`03_core_views.sql`, `04_mart_star_schema.sql`)

| Object | Expected |
|---|---:|
| mart.fact_orders rows | 99,441 |
| mart.fact_order_items rows | 112,650 |
| Sum of `order_value_brl` in fact_orders | 13,591,643.70 |

`dq.v_checks`:

| # | Check | Failed rows | Total rows | Failed % |
|---:|---|---:|---:|---:|
| 1 | Delivered order without delivery date | 8 | 99,441 | 0.01 |
| 2 | Order without any item | 775 | 99,441 | 0.78 |
| 3 | Order without review | 768 | 99,441 | 0.77 |
| 4 | Purchase timestamp not convertible | 0 | 99,441 | 0.00 |
| 5 | Handed to carrier before approval | 1,359 | 99,441 | 1.37 |
| 6 | Handed to carrier before purchase | 166 | 99,441 | 0.17 |
| 7 | Delivered to customer before carrier pickup | 23 | 99,441 | 0.02 |
| 8 | Not delivered, but delivery date set | 6 | 99,441 | 0.01 |
| 9 | Price missing or <= 0 | 0 | 112,650 | 0.00 |
| 10 | Duplicate review_id rows | 814 | 99,224 | 0.82 |
| 11 | Product without category | 610 | 32,951 | 1.85 |
| 12 | Category missing in translation file | 13 | 32,951 | 0.04 |
| 13 | Item with unknown seller | 0 | 112,650 | 0.00 |

Overall: 4,542 failed of 1,185,954 checked rows → **DQ Score 99.62 %**, 10 of 13 checks with findings.

## Step 4 – DAX measures (Power BI card visuals)

| Measure | No filter (all data) | Analysis period 2017-01 … 2018-08 |
|---|---:|---:|
| Orders | 99,441 | 99,092 |
| Order Items | 112,650 | 112,279 |
| Revenue (BRL) | 13,591,643.70 | 13,541,712.78 |
| Freight (BRL) | 2,251,909.54 | 2,244,490.79 |
| Active Suppliers | 3,095 | 3,068 |
| Avg Order Value (BRL) | 137.75 | 137.68 |
| Freight Share % | 14.21 % | – |
| Cancellation Rate % | 1.24 % | 1.19 % |
| Customer OTD % | 93.23 % | 93.21 % |
| Late Orders | 6,535 | – |
| Avg Lead Time (days) | 12.50 | 12.48 |
| Avg Days Late (late orders) | 10.62 | 10.62 |
| Complaint Rate % | 14.73 % | 14.67 % |
| Complaint Rate % (late) | 62.46 % | 62.5 % |
| Complaint Rate % (on time) | 9.31 % | 9.3 % |
| Supplier OTD % | 90.65 % | 90.77 % |
| Late Handovers | 10,423 | 10,258 |
| Avg Seller Processing (days) | 2.80 | 2.77 |
| Supplier Complaint Rate % | 16.15 % | 16.11 % |
| DQ Score % | 99.62 % | (not date-filtered) |

Year comparison (slicer Year):

| | 2017 | 2018 Jan–Aug | 2017 Jan–Aug |
|---|---:|---:|---:|
| Orders | 45,101 | 53,991 | 22,968 |
| Revenue (BRL) | 6,155,806.98 | 7,385,905.80 | 3,113,000.32 |
| Customer OTD % | 94.35 % | 92.27 % | 96.50 % |
| Supplier OTD % | 90.23 % | 91.21 % | 91.01 % |

Revenue YoY % for 2018 Jan–Aug vs. 2017 Jan–Aug: **+137.3 %**

## Step 5 – Scorecard checks (analysis period)

| Check | Expected |
|---|---:|
| ABC: A / B / C suppliers | 540 / 758 / 1,770 |
| Revenue share A / B / C | 80.0 % / 15.0 % / 5.0 % |
| Suppliers with ≥ 20 items | 890 |
| … of which red (Supplier OTD < 90 %) | 267 |
| Share of all late handovers caused by these 267 | 61.6 % |
| Share of late handovers caused by the top 10 % of suppliers | 78.4 % |
| Worst customer state (≥ 500 orders) by Customer OTD | MA – 82.5 % |
| Lowest monthly Customer OTD | 2018-03 – 81.0 % |

## Step 6 – Page 2 "Supplier Scorecard" (analysis period)

| Check | Expected |
|---|---:|
| `dim_seller[ABC Segment]` A / B / C / blank | 540 / 758 / 1,770 / 27 |
| `dim_seller[OTD Segment]` Green / Amber / Red / blank | 1,909 / 244 / 799 / 143 (Red includes 117 sellers with 0 % OTD) |
| Table rows (filter Is Relevant Supplier = 1) | 890 |
| Row 1 by revenue | `4869f7a5…` · SP · 1,156 items · 229,472.63 BRL · A · OTD 94.6 % · 2.31 days · complaints 13.9 % |
| Worst large supplier (rank 5) | `7c67e144…` · SP · 1,364 items · 187,923.89 BRL · A · OTD 69.4 % · 11.49 days · complaints 29.6 % |
| Relevant red suppliers by ABC A / B / C | 143 / 110 / 14 |
| Scatter: relevant suppliers with OTD < 90 % and complaints > 16 % | 166 |
| 143 red A-suppliers: share of revenue / of all late handovers | 21.2 % / 48.6 % |

## Step 7 – Drill-through page "Supplier Detail" (drill from `7c67e144…`)

| Check | Expected |
|---|---:|
| Header | Supplier 7c67e144… · itaquaquecetuba (SP) |
| Order Items / Revenue (BRL) | 1,364 / 187,923.89 |
| Supplier OTD % / Late Handovers | 69.4 % / 417 |
| Avg Seller Processing (days) / Supplier Complaint Rate % | 11.5 / 29.6 % |
| Lowest monthly Supplier OTD | 2017-12 – 19.4 % (2018-01: 40.6 %) |
| Highest monthly volume | 2018-03 – 193 items |
| Processing time 2017-06 → 2018-01 | 5.6 → 17.1 days |
| Top category | office_furniture – 1,233 items (OTD 70.3 %) |

Story: volume tripled after Black Friday 2017, processing time tripled, OTD collapsed → a capacity problem, not random noise.

## Step 8 – Page 3 "Delivery & Lead Time" (analysis period)

| Check | Expected |
|---|---:|
| Late Orders / Customer OTD % | 6,532 / 93.2 % |
| Avg Lead Time / Avg Days Late (late orders) | 12.5 / 10.6 days |
| Pareto: total late handovers | 10,258 |
| Pareto: #1 supplier | `7c67e144…` – 417 late handovers (4.1 % cumulative) |
| Pareto: cumulative share top 10 / top 50 suppliers | 17.8 % / 41.3 % |
| Top 10 % of suppliers (307) | 78.4 % of all late handovers |
| Decomposition tree: Late Orders → state | SP 1,817 · RJ 1,495 · MG 520 · BA 396 |
| … SP → month | 2018-08 285 · 2018-03 280 · 2017-11 202 |
| Highest avg lead time | 2018-02 – 16.9 days (2017-11: 15.1 · 2017-12: 15.3) |
| Complaint Rate % late vs. on time | 62.5 % vs. 9.3 % |
