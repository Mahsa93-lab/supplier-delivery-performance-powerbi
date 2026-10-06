# KPI-Definitionen / KPI definitions

Every KPI has one formula, one grain and one data source – the same standard used in industrial quality reporting.

## Grain
- **fact_orders** – one row per order (99,441). Used for the customer view.
- **fact_order_items** – one row per order item (112,650). Used for the supplier view.

Why two? 775 canceled/unavailable orders have no items. Measured on item level, the cancellation rate would drop from 1.24 % to 0.47 % – a classic grain error.

## Customer view (fact_orders)

| KPI | Definition (DE) | Formula | Threshold |
|---|---|---|---|
| **Customer OTD %** | Anteil der zugestellten Bestellungen, die bis zum zugesagten Liefertermin beim Kunden waren | orders with `delivery_on_time = 1` ÷ orders with a delivery date | ≥ 92 % |
| **Avg Lead Time (days)** | Durchlaufzeit von Bestellung bis Zustellung | Ø `DATEDIFF(day, purchase_ts, delivered_customer_ts)` | trend ↓ |
| **Avg Days Late** | Ø Verspätung der verspäteten Bestellungen | Ø (delivery date − promised date), late orders only | trend ↓ |
| **Complaint Rate %** | Anteil der bewerteten Bestellungen mit 1–2 Sternen (Reklamations-Proxy) | orders with worst review ≤ 2 ÷ reviewed orders | ≤ 10 % |
| **Cancellation Rate %** | Anteil stornierter / nicht verfügbarer Bestellungen | status canceled or unavailable ÷ all orders | ≤ 1 % |

## Supplier view (fact_order_items)

| KPI | Definition (DE) | Formula | Threshold |
|---|---|---|---|
| **Supplier OTD %** | Anteil der Positionen, die der Lieferant fristgerecht an den Spediteur übergeben hat | items with `handover_on_time = 1` ÷ items with known handover | ≥ 95 % green · 90–95 % amber · < 90 % red |
| **Avg Seller Processing (days)** | Bearbeitungszeit beim Lieferanten (Freigabe → Übergabe) | Ø `DATEDIFF(day, approved_ts, delivered_carrier_ts)`; illogical sequences excluded | ≤ 3 days |
| **Supplier Complaint Rate %** | Reklamationsquote je Lieferant | items with worst review ≤ 2 ÷ reviewed items | ≤ 12 % |
| **ABC Class** | Lieferantenklassifizierung nach kumuliertem Umsatzanteil | A ≤ 80 % · B ≤ 95 % · C rest | – |
| **Relevant supplier** | Mindestvolumen für Rankings | ≥ 20 items in the selected period | – |

## Data quality

| KPI | Definition (DE) | Formula | Threshold |
|---|---|---|---|
| **DQ Score %** | Anteil der geprüften Datensätze ohne Befund | 1 − Σ failed rows ÷ Σ checked rows over 13 checks | ≥ 99 % |

## Assumptions
- Thresholds are illustrative and documented so that a business owner can change them in one place.
- `delivered_carrier_ts` is stored per order; for orders with several suppliers all items share the same handover date.
- Reviews are aggregated per order with the **worst** score (conservative quality view).
- Analysis period for trends: 2017-01-01 to 2018-08-31 (2016 and Sep/Oct 2018 contain only 349 orders).
- Currency: BRL; project 2 adds daily ECB rates and converts to EUR.
