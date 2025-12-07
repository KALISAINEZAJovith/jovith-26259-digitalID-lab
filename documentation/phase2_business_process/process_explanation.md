
**Student:** KALISA INEZA Jovith | **ID:** 26259  
**Project:** Digital Health Lab Management with Privacy & Access Controls  
**Database:** mon_26259_kalisa_healthLabPrivacy_db 

---

## 1. BUSINESS PROCESS SCOPE

**Process Name:** Laboratory Test Request, Processing, and Privacy-Controlled Result Distribution

**Objective:** Streamline laboratory testing workflow while ensuring strict patient data privacy compliance through automated access controls, abnormal value detection, and comprehensive audit trails.

**MIS Relevance:** Supports healthcare Management Information Systems through operational efficiency (automated test routing), clinical decision support (real-time abnormal value alerts), regulatory compliance (complete audit trail for Rwanda Data Protection Act), quality assurance (validation checkpoints), and resource management (test volume analytics).

---

## 2. KEY ENTITIES & ROLES

**Doctor** - Initiates lab test requests, accesses patient records with consent validation, reviews results, responds to abnormal value alerts. Authorization: Healthcare Provider level.

**Lab Technician** - Processes test requests, collects/labels samples, runs analyses, enters results. Access restricted to assigned specimens only. Authorization: Lab Staff level.

**Patient** - Provides consent for data access, views own results through portal. Authorization: Data Subject with full access to personal data.

**PL/SQL System** - Validates privacy permissions (RBAC), checks results against normal ranges, enforces business rules (working hours/holidays), triggers alerts on abnormal values, logs all access attempts.

**Privacy Auditor** - Monitors access patterns, investigates violations, generates compliance reports. Read-only access to audit logs. Authorization: Auditor level.

---

## 3. PROCESS FLOW (Using Swimlanes)

**DOCTOR LANE:** (1) Requests lab test with patient ID and test type → (2) Requests access to patient historical records → (3) Receives abnormal value alert if triggered

**LAB TECHNICIAN LANE:** (4) Receives authorized test request in queue → (5) Collects biological sample and applies barcode label → (6) Processes sample through lab equipment → (7) Manually enters test results

**SYSTEM LANE:** (8) Validates doctor's authorization against patient consent registry → **DECISION: Privacy Check** → If no consent: DENY ACCESS + LOG VIOLATION → If consent exists: GRANT ACCESS → (9) Validates entered results against normal reference ranges → **DECISION: Abnormal Value?** → If YES: TRIGGER ALERT to doctor → If NO: Store results with audit log entry

**PATIENT LANE:** (10) Provides/revokes consent for data access → (11) Views results through authenticated patient portal

**AUDITOR LANE:** (12) Reviews access logs for compliance monitoring → (13) Generates privacy violation reports → Process END

---

## 4. MIS FUNCTIONAL COMPONENTS

**Transaction Processing (OLTP):** Real-time test order entry, result recording, access validation with foreign key constraints and row-level locking for data integrity.

**Decision Support:** Abnormal result pattern analysis for population health trends, lab efficiency metrics (turnaround time tracking), privacy risk assessment (unusual access pattern detection), resource utilization monitoring.

**Compliance & Reporting:** Audit trail queries (who/what/when), violation reports (failed access attempts), consent management tracking, regulatory export for health authority inspections.

---

## 5. ORGANIZATIONAL IMPACT

**Efficiency Gains:** Automated routing eliminates manual handoffs, validation rules catch errors immediately, only clinically significant abnormalities trigger notifications (reduces alert fatigue).

**Risk Mitigation:** Layered access controls enforce least-privilege principle, audit trails demonstrate due diligence for data protection, abnormal value alerts prevent missed critical diagnoses.

**Stakeholder Benefits:** Patients gain confidence in data privacy with faster result availability; doctors receive actionable alerts without information overload; lab staff follow structured workflows reducing errors; hospital achieves regulatory compliance with demonstrable controls.

---

## 6. ANALYTICS OPPORTUNITIES (BI Integration)

**Operational Dashboards:** Lab test volume by type/time, average turnaround time from request to result, technician workload distribution, equipment utilization rates.

**Clinical Intelligence:** Abnormal result frequency by test type, seasonal disease trends, high-risk patient identification, comparative analysis against population norms.

**Privacy Compliance:** Access attempt success/failure rates by role, consent status tracking, violation pattern detection, audit completeness verification, regulatory readiness scoring.

**Resource Optimization:** Peak demand forecasting, staffing requirement predictions, supply inventory optimization, cost-per-test analysis by department.