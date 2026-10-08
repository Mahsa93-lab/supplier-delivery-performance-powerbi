# Lieferanten- und Liefertreue-Dashboard (SQL Server + Power BI)

[English](README.md) · **Deutsch** 

> Welche Lieferanten liefern verspätet oder verursachen Reklamationen – und wo sollte der Einkauf zuerst ansetzen?

![Executive Overview](images/01_executive_overview.png)

## Ausgangslage
Einkauf und Qualitätsmanagement brauchen eine gemeinsame, verlässliche Sicht auf die Lieferantenleistung. In der Praxis liegen die Daten in mehreren Systemen, Kennzahlen werden je Team unterschiedlich definiert, und niemand weiß genau, wie belastbar die Zahlen sind. Dieses Projekt bildet die gesamte Kette ab – Rohdaten → bereinigtes Datenmodell → KPI-Scorecard → Ursachenanalyse – und macht die Datenqualität auf einer eigenen Berichtsseite sichtbar.

## Wichtigste Erkenntnisse (Analysezeitraum 01/2017 – 08/2018)
1. **Verspätung treibt Reklamationen:** 62,5 % der verspäteten Bestellungen erhalten eine 1–2-Sterne-Bewertung, bei pünktlichen nur 9,3 % (**6,7-mal so häufig**).
2. **Die Probleme sind konzentriert:** 10 % der Lieferanten verursachen **78,4 %** aller verspäteten Übergaben. 143 rote A-Lieferanten (Liefertreue < 90 %) erzielen 21 % des Umsatzes, verursachen aber **49 %** der verspäteten Übergaben.
3. **Ursache ist Kapazität, nicht Zufall:** Beim schlechtesten Großlieferanten (Rang 5 nach Umsatz, Büromöbel) verdreifachte sich das Volumen nach dem Black Friday 2017. Die Bearbeitungszeit stieg von 5,6 auf 17,1 Tage, die Liefertreue fiel im Dezember 2017 auf 19 %.
4. **ABC-Analyse:** 18 % der Lieferanten (A-Klasse) erzielen 80 % des Umsatzes.

**Empfehlung:** Lieferantenentwicklung auf die kurze Liste der roten A-Lieferanten konzentrieren statt auf alle 3.000 – und mit ihnen vor Spitzenzeiten verbindliche Kapazitätspläne vereinbaren.

## Daten
- **Quelle:** [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle, CC BY-NC-SA 4.0) – 99.441 Bestellungen, 112.650 Positionen, 3.095 Verkäufer, 8 Tabellen
- **Übertragung auf den Einkauf:** Verkäufer = Lieferant · Übergabe an den Spediteur vor der Versandfrist = Liefertreue des Lieferanten · 1–2-Sterne-Bewertung = Reklamation
- **Datenqualität:** 13 automatisierte Prüfungen, **DQ-Score 99,62 %**; für jeden Befund gibt es eine dokumentierte Behandlungsregel (Seite 4 des Berichts)

## Architektur
```
CSV (8 Dateien) ──Python──► stg (roh, Text) ──Views──► core (typisiert, bereinigt) ──Views──► mart (Sternschema) ──► Power BI
                                                                          └──► dq.v_checks (13 Prüfungen) ────────┘
```
- **Zwei Faktentabellen mit unterschiedlicher Granularität:** `fact_orders` (Kundensicht, enthält auch die 775 Bestellungen ohne Positionen – sonst wäre die Stornoquote falsch) und `fact_order_items` (Lieferantensicht)
- Rohdaten werden nie verändert; alle Regeln liegen in SQL-Views und sind in Git versioniert

![Datenmodell](images/08_data_model.png)

## Bericht
| Seite | Leitfrage | Inhalte |
|---|---|---|
| Executive Overview | Wie stehen wir insgesamt da? | KPI-Karten, Liefertreue-Trend mit 92-%-Ziel, Umsatztrend, schwächste Bundesstaaten |
| Supplier Scorecard | Um welche Lieferanten müssen wir uns zuerst kümmern? | ABC-Klasse und Ampel, Risikomatrix, Lesezeichen „kritische A-Lieferanten" per Klick |
| Supplier Detail (Drillthrough) | Warum liefert dieser Lieferant zu spät? | Volumen vs. Bearbeitungszeit, monatliche Liefertreue, Produktmix |
| Delivery & Lead Time | Wo und warum entstehen Verspätungen? | Pareto, Analysebaum, Reklamationsquote verspätet vs. pünktlich |
| Data Quality | Können wir den Zahlen vertrauen? | DQ-Score, 13 Prüfungen nach Dimension, Behandlungsregeln |

| Supplier Scorecard | Supplier Detail |
|---|---|
| ![Scorecard](images/02_supplier_scorecard.png) | ![Detail](images/03_supplier_detail.png) |
| **Delivery & Lead Time** | **Data Quality** |
| ![Lieferung](images/04_delivery_lead_time.png) | ![Datenqualität](images/05_data_quality.png) |

## Qualität und Governance
- **Getestete Zahlen:** `sql/05_validate.sql` (15 PASS/FAIL-Tests) und `powerbi/validate_measures.dax` gleichen jede Kennzahl mit [docs/expected-results.md](docs/expected-results.md) ab. Die Tests haben zwei echte DAX-Fehler aufgedeckt (`BLANK() = 0` ist TRUE; `DIVIDE(BLANK, n)` blendete 117 Lieferanten mit 0 % Liefertreue aus) – beide behoben.
- **Zeilenbasierte Sicherheit (RLS):** Rolle `Region SP` (`dim_customer[state] = "SP"`), geprüft mit „Anzeigen als" → [Screenshot](images/06_rls_view_as_sp.png)
- **Performance:** alle Visuals < 350 ms in der Leistungsanalyse (Sternschema, Importmodus) → [Screenshot](images/07_performance_analyzer.png)
- **Dokumentierte Kennzahlen:** [docs/KPI-Definitionen.md](docs/KPI-Definitionen.md) · 36 Measures in Anzeigeordnern, Beschreibungen für die zentralen Kennzahlen

## Ausführen
1. SQL Server Express, SSMS, ODBC Driver 18 for SQL Server und Power BI Desktop installieren
2. `sql/01_create_database.sql` in SSMS ausführen
3. `pip install -r requirements.txt` → `python python\load_olist_to_sqlserver.py --csv-dir C:\data\olist`
4. `sql/02_profiling.sql`, `sql/03_core_views.sql`, `sql/04_mart_star_schema.sql` ausführen
5. `sql/05_validate.sql` ausführen – alle 15 Zeilen müssen **PASS** zeigen
6. `powerbi/supplier_performance.pbix` öffnen (Quelle `localhost\SQLEXPRESS`, Datenbank `olist`) → Aktualisieren
7. PDF-Version des Berichts: `powerbi/supplier_performance.pdf`

## Werkzeuge
SQL Server (T-SQL, Views, Sternschema) · Python (pandas, SQLAlchemy) · Power BI (DAX, TMDL, Drillthrough, Lesezeichen, RLS, Leistungsanalyse)

## Bezug zu meiner Erfahrung
In 2,5 Jahren im Kundenprojekt bei der BMW AG (u. a. Fachbereich „Datenanalyse, Lieferantenaudit") habe ich Qualitäts- und Lieferantendaten aus SAP und weiteren Quellsystemen ausgewertet, Kennzahlen mit Fachbereichen definiert, die Datenqualität geprüft und Prozesse nach Six Sigma DMAIC verbessert. Dieses Projekt überträgt genau diesen Ansatz – messen, Ursache verstehen, Maßnahme ableiten – auf einen öffentlichen Datensatz und einen modernen BI-Stack.

## Nächste Schritte
- Pipeline in ein Lakehouse mit täglicher Aktualisierung und EUR-Umrechnung überführen → Projekt 2
- Wöchentliche Management-Zusammenfassung aus diesen KPIs von einem KI-Agenten erstellen lassen → Projekt 4

## Portfolio
Vier zusammenhängende Projekte zu vertrauenswürdigen Daten und KI in der Supply Chain – vom Dashboard über die Pipeline bis zum Agenten:

| # | Projekt | Fragestellung | Stack |
|---|---|---|---|
| 1 | **Lieferanten- & Lieferperformance** *(dieses Repository)* | Welche Lieferanten verursachen Verspätungen – und was kosten sie an Reklamationen? | SQL Server · Power BI · DAX |
| 2 | [Lakehouse-Pipeline Supply Chain](https://github.com/Mahsa93-lab/lakehouse-supply-chain-pipeline) | Lassen sich dieselben Kennzahlen täglich, automatisch und hinter einem Datenqualitäts-Gate erzeugen? | Databricks · PySpark · Delta Lake |
| 3 | [Assistent EU AI Act & DSGVO](https://github.com/Mahsa93-lab/eu-ai-act-rag-assistant) | Kann ein KI-Assistent Rechtsfragen mit überprüfbaren Quellen beantworten? | RAG · OpenAI · FastAPI · Docker |
| 4 | [KI-Agent für KPI-Wochenberichte](https://github.com/Mahsa93-lab/ai-kpi-reporting-agent) | Kann ein KI-Agent die wöchentliche Management-Summary schreiben – ohne eine einzige ungeprüfte Zahl? | n8n · MCP · SPC · Docker |

Die Projekte bauen aufeinander auf: Projekt 2 liefert dieselben Zahlen wie Projekt 1 auf den Cent genau (99.441 Bestellungen, 13.591.643,70 BRL Umsatz); der Agent in Projekt 4 liest die Gold-Tabellen aus Projekt 2 und nutzt die Such-API aus Projekt 3.

---
*Autorin: Mahsa Ahmadi · Ausschließlich öffentliche Daten; es wurden keine unternehmensinternen Daten verwendet.*
