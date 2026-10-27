# FORM 2
### THE PATENTS ACT, 1970 (39 of 1970)
### &
### THE PATENT RULES, 2003
## COMPLETE SPECIFICATION
(See Section 10 and Rule 13)

---

### 1. TITLE OF THE INVENTION
**A MAINFRAME-BASED AUTOMATED BATCH SYSTEM AND METHOD FOR SUBSCRIPTION BILLING, PAYMENT VALIDATION AND REVENUE REPORTING**

---

### 2. APPLICANT(S)

| Full Name | Nationality | Address |
| :--- | :--- | :--- |
| **Vishwakarma Institute of Technology** | Indian | 666, Upper Indiranagar, Bibwewadi, Pune, Maharashtra, India – 411 037 |
| **Vishwakarma University** | Indian | Survey No 2, 3, 4, Kondhwa Main Rd, Laxmi Nagar, Betal Nagar, Kondhwa, Pune, Maharashtra, India – 411 048 |

---

### 3. INVENTOR(S)

| Full Name | Nationality | Address / Affiliation | Email ID | Phone No. |
| :--- | :--- | :--- | :--- | :--- |
| **Prof. Madhura Sanap** | Indian | Department of Computer Science & Engineering (Data Science), Vishwakarma Institute of Technology, Pune | madhura.sanap@vit.edu | +91-9766001130 |
| **Aditi Prakash Kadam** | Indian | Department of Computer Science & Engineering (Data Science), Vishwakarma Institute of Technology, Pune | aditi.kadam24@vit.edu | +91-9209253813 |
| **Sharayu Abhijit Itkikar** | Indian | Department of Computer Science & Engineering (Data Science), Vishwakarma Institute of Technology, Pune | sharayu.itkikar24@vit.edu | +91-8446012951 |
| **Smruti Babruwan Gadave** | Indian | Department of Computer Science & Engineering (Data Science), Vishwakarma Institute of Technology, Pune | smruti.1252040011@vit.edu | +91-9511746098 |

---

### 4. PREAMBLE TO THE DESCRIPTION
The following specification particularly describes the invention and the manner in which it is to be performed:

---

### 5. TECHNICAL FIELD OF THE INVENTION
The present invention relates generally to enterprise data processing architectures and batch execution environments. More particularly, the invention relates to a mainframe-based, computer-implemented system, method, and architecture utilizing Job Control Language (JCL), Common Business-Oriented Language (COBOL), Virtual Storage Access Method (VSAM) Key-Sequenced Datasets (KSDS), and sequential dataset pipelines for automated recurring subscription billing, multi-rule payment validation, exception isolation, and revenue reconciliation and reporting.

---

### 6. BACKGROUND OF THE INVENTION AND PRIOR ART
Subscription-based commerce has emerged as a dominant operational model across enterprise software (SaaS), telecommunications, digital media/OTT platforms, utilities, insurance, and banking. Such recurring models require systematic periodic processing of millions of subscriber records, including verification of customer account standing, validation of plan entitlements, computation of term-dependent tiered discounts, statutory tax calculations, payment reconciliation against bank feeds, and corporate revenue accounting.

Mainframe computing environments (e.g., IBM Z architecture running z/OS and MVS) are globally recognized for handling large-scale, record-oriented batch workloads with extreme reliability, data throughput, and determinism. Within these environments, Job Control Language (JCL) orchestrates the execution of modular COBOL processing programs operating on VSAM KSDS indexed clusters and fixed-block sequential datasets.

#### Shortcomings of Existing Technology
1. **Manual and Fragmented Workflows:** In many enterprise systems, recurring billing is performed through loosely integrated tools, ad-hoc scripts, or manual operator interventions. As subscriber volume scales into millions of records, processing latency compounds and operational errors proliferate.
2. **Batch Vulnerability and Abends:** Conventional batch setups often abend (abnormally terminate) or halt processing whenever a single corrupt, missing, or inactive customer/plan record is encountered. Resolving such abends requires operator intervention, dataset clean-ups, and rerun overheads, which delays entire corporate financial close cycles.
3. **Inconsistent Discount and Statutory Calculations:** When billing rules are dispersed across external general-purpose billing engines or online payment gateways, rules regarding duration tiers, partial periods, and tax applications are applied inconsistently.
4. **Lack of Synchronized Payment Reconciliation:** Online transaction-oriented systems depend heavily on real-time API calls to third-party payment gateways. In contrast, large-scale financial enterprises settle via batch clearinghouse feeds. Existing systems lack a unified batch pipeline that classifies payments into exact categories (SUCCESS, AMOUNT MISMATCH, FAILED PAYMENT, DUPLICATE TRANSACTION) while automatically preserving valid transactions and isolating non-conforming items into an audit-ready repository without halting the batch.

The present invention solves these technical challenges through an integrated JCL-orchestrated batch pipeline executing compiled COBOL programs with conditioned step execution, automated exception routing, and dual-layer data storage.

---

### 7. OBJECTIVES OF THE INVENTION
The primary objectives of the present invention are:
1. To provide an automated mainframe batch system and computer-implemented method for recurring subscription billing of customers categorized by subscription tier.
2. To validate customer, subscription, plan, and billing-date records prior to bill generation and autonomously divert defective records to a centralized exception dataset (`EXCEPTION.DAT`).
3. To calculate final bill amounts through an integrated algorithmic pricing engine that computes duration-based discount bands (3–6 months: 5%, 7–12 months: 10%, >12 months: 15%) and statutory tax (18% on net base).
4. To reconcile payment transactions against generated bills and classify each transaction into definitive states: successful payment, amount mismatch (partial/underpayment), failed status, or duplicate transaction ID.
5. To aggregate billed, collected, and outstanding revenues overall and categorized by subscription plan.
6. To format and spool three distinct management registers: a Detailed Billing Register (`BILLRPT.TXT`), an Executive Revenue Summary (`REVRPT.TXT`), and an Exception Rejection Audit Log (`EXCPRPT.TXT`).
7. To provide return-code-controlled conditional step execution (`COND=(4,LT)`) that prevents batch halting on data exceptions and ensures 100% auditability and repeatability.

---

### 8. BRIEF DESCRIPTION OF THE ACCOMPANYING DRAWINGS
The accompanying drawings illustrate exemplary embodiments of the invention:

* **FIG. 1** is a block diagram illustrating the overall system architecture (100), comprising input datasets (110), JCL batch job control module (120), COBOL processing programs (130), data layer (140), exception dataset (150), and formatted reports (160).
* **FIG. 2** is a process flow diagram of the batch execution and exception diversion workflow (201–209).
* **FIG. 3** is a schematic diagram illustrating the dataset and file operations across the sequenced steps of JCL job `SUBBILL01`.
* **FIG. 4** is a detailed logic diagram illustrating the record validation checks (301–304), billing calculation rules (311–314), and payment matching rules (321–324).

---

### 9. DETAILED DESCRIPTION OF THE INVENTION
Referring to the drawings and descriptions:

#### System Architecture (FIG. 1)
As illustrated in **FIG. 1**, the system (100) comprises:
* **Input Datasets (110):**
  * Customer Master Dataset (111, `PROD.SUBSYS.CUSTMAST.KSDS`): VSAM KSDS keyed by `CUST-ID` (offset 0, length 10 bytes).
  * Subscription Master Dataset (112, `PROD.SUBSYS.SUBMAST.KSDS`): VSAM KSDS keyed by `SUB-ID` (offset 0, length 10 bytes).
  * Plan Master Dataset (113, `PROD.SUBSYS.PLANMAST.KSDS`): VSAM KSDS keyed by `PLAN-ID` (offset 0, length 8 bytes).
  * Payment Input Dataset (114, `PROD.SUBSYS.PAYMENT.DATA`): Fixed-block sequential dataset of incoming financial transactions.
* **JCL Batch Job Control Module (120):** Job `SUBBILL01` orchestrating steps `STEP01` through `STEP07` using Data Definition (DD) statements, dataset dispositions (`DISP`), space allocations, DCB parameters, and return-code conditional checking (`COND=(4,LT)`).
* **COBOL Processing Programs (130):**
  * `SUBVAL` (131): Step 2 - Record Validation Program.
  * `BILLPROC` (132): Step 3 - Billing Calculation Engine.
  * `PAYPROC` (133): Step 4 - Payment Matching and Reconciliation Program.
  * `REVPROC` (134): Step 5 - Revenue Aggregation Program.
  * `REPORT` (135): Step 6 - Spool Report Generator.
* **Data Layer (140):** Comprising VSAM KSDS clusters for indexed master entities and sequential files for transaction logs.
* **Exception Dataset (150):** `PROD.SUBSYS.EXCEPTION.DATA` (`EXCEPTION.DAT`), a common disposition dataset receiving all non-conforming, inactive, corrupt, mismatched, or failed records.
* **Spool Output Reports (160):** Detailed Billing Register (161, `BILLRPT.TXT`), Executive Revenue Summary (162, `REVRPT.TXT`), and Exception Audit Log (163, `EXCPRPT.TXT`).

---

#### Step Sequencing and Execution Logic (FIG. 2 & FIG. 3)
1. **Preparation and Job Submission (201, 202):** The batch operator or automated scheduler submits JCL job `SUBBILL01`. In `STEP01`, IDCAMS utility verifies catalog allocations, deletes previous run scratch datasets, and initializes clusters.
2. **Record Validation (203 - SUBVAL):** `SUBVAL` sequentially reads `SUBMAST.DAT` and performs four technical checks:
   * **Rule 301:** In-memory or indexed lookup verifies `CUST-ID` exists in `CUSTMAST` and `CUST-STATUS = 'A'` (Active).
   * **Rule 302:** Verifies `SUB-STATUS = 'A'` (Active).
   * **Rule 303:** Verifies `PLAN-ID` exists in `PLANMAST` and `PLAN-STATUS = 'A'`.
   * **Rule 304:** Verifies `SUB-NEXT-BILL-DATE` is syntactically valid and due for the billing period.
   * *Diversion (208):* If any check fails, an exception record is written to `EXCEPTION.DAT` (specifying program source, record key, error code e.g. `ERR001`–`ERR006`, error description, and timestamp), and `RETURN-CODE` is set to 4. Valid records are written to `VALIDSUB.DAT`.
3. **Billing Calculation (204 - BILLPROC):** Governed by `COND=(4,LT,STEP02)`. `BILLPROC` reads `VALIDSUB.DAT` and applies:
   * **Rule 311:** Base Amount = Plan Base Amount.
   * **Rule 312 (Duration Discount):**
     $$\text{Discount \%} = \begin{cases} 0\% & \text{if duration} < 3 \text{ months} \\ 5\% & \text{if } 3 \le \text{duration} \le 6 \text{ months} \\ 10\% & \text{if } 7 \le \text{duration} \le 12 \text{ months} \\ 15\% & \text{if duration} > 12 \text{ months} \end{cases}$$
   * **Rule 313 (Tax):** Statutory tax at 18% computed on the discounted base:
     $$\text{Discounted Base} = \text{Base Amount} \times \left(1 - \frac{\text{Discount \%}}{100}\right)$$
     $$\text{Tax Amount} = \text{Discounted Base} \times 0.18$$
   * **Rule 314 (Final Bill Amount):**
     $$\text{Final Bill Amount} = \text{Discounted Base} + \text{Tax Amount}$$
   * Writes each calculated item to `BILLS.DAT`.
4. **Payment Matching and Reconciliation (205 - PAYPROC):** Governed by `COND=(4,LT,STEP03)`. `PAYPROC` loads calculated bills and reads `PAYMENT.DAT`:
   * **Rule 324:** Checks in-memory cache for duplicate `TXN-ID` $\rightarrow$ Diverts to `EXCEPTION.DAT` (`ERR010`).
   * **Rule 323:** Evaluates payment status $\rightarrow$ If `FAILED`, diverts to `EXCEPTION.DAT` (`ERR011`).
   * **Rule 322:** Compares `PAY-AMOUNT` against `BILL-FINAL-AMT` $\rightarrow$ If `PAY-AMOUNT` < `BILL-FINAL-AMT`, classifies as `AMOUNT MISMATCH` and diverts to `EXCEPTION.DAT` (`ERR013`).
   * **Rule 321:** If `PAY-AMOUNT` matches bill, classifies as `SUCCESS` and writes to `PAYOUT.DAT`.
5. **Revenue Aggregation (206 - REVPROC):** Reads `BILLS.DAT` and `PAYOUT.DAT`, aggregates billed, collected, and outstanding amounts by plan and in total, and writes `REVENUE.DAT`.
6. **Report Generation (207 - REPORT):** Spools formatted registers `BILLRPT.TXT`, `REVRPT.TXT`, and `EXCPRPT.TXT` to SYSOUT.
7. **Audit Review and Archival (209):** `STEP07` archives datasets to tape or secondary direct access storage.

---

### 10. BEST METHOD OF PERFORMANCE
In a preferred implementation, the system is executed on an enterprise mainframe computing system (IBM z/Architecture) under control of Job Control Language job `SUBBILL01`. Input datasets comprise `PROD.SUBSYS.CUSTMAST.KSDS` (100-byte records, key at offset 0 length 10), `PROD.SUBSYS.SUBMAST.KSDS` (80-byte records, key at offset 0 length 10), and `PROD.SUBSYS.PLANMAST.KSDS` (60-byte records, key at offset 0 length 8).

Programs `SUBVAL`, `BILLPROC`, `PAYPROC`, `REVPROC`, and `REPORT` are compiled under IBM Enterprise COBOL for z/OS. Execution return codes are strictly maintained: `RC=0000` indicates perfect execution; `RC=0004` indicates warnings/non-fatal exceptions handled and diverted; `RC=0008` or higher triggers conditional job interruption via JCL `COND` parameters.

---

### 11. CLAIMS

**WE CLAIM:**

1. A mainframe-based computer-implemented system for automated recurring subscription billing, payment validation, and revenue reporting, comprising:
   - a data storage repository storing a plurality of input datasets comprising a customer master dataset, a subscription master dataset, a plan master dataset, and a payment transaction dataset;
   - a job control module configured to orchestrate a batch job comprising a plurality of sequenced job execution steps and to evaluate a return code of each preceding job execution step prior to initiating a subsequent job execution step;
   - a validation program configured to read records from said subscription master dataset, verify active status of associated customer records in said customer master dataset and plan records in said plan master dataset, verify due billing dates, and automatically route records failing verification to an exception dataset while outputting validated records to a validated subscription dataset;
   - a billing calculation program configured to read said validated subscription dataset, determine a duration-based discount percentage based on subscription duration, apply statutory tax to a discounted base amount to compute a final bill amount, and write generated bills to a billing dataset;
   - a payment validation program configured to match records from said payment transaction dataset against said billing dataset, classify each transaction into one of a plurality of predetermined transaction states comprising successful, amount mismatch, failed, and duplicate, route non-successful transactions to said exception dataset, and write verified successful transactions to a payment output dataset;
   - a revenue aggregation program configured to compute total billed revenue, total collected revenue, and net outstanding receivables; and
   - a reporting program configured to format and generate a detailed billing report, a revenue summary report, and an exception audit log;
   wherein said batch job executes without halting upon occurrence of individual record defects by isolating said defective records in said exception dataset.

2. The system as claimed in claim 1, wherein said customer master dataset, subscription master dataset, and plan master dataset are configured as Virtual Storage Access Method (VSAM) Key-Sequenced Datasets (KSDS), and said payment transaction dataset and exception dataset are configured as fixed-block sequential datasets.

3. The system as claimed in claim 1, wherein said validation program sets a step completion return code to 0 upon zero defects and to 4 upon encountering one or more defective records, wherein said return code of 4 satisfies a JCL conditional execution parameter allowing said subsequent billing calculation program to execute.

4. The system as claimed in claim 1, wherein said duration-based discount percentage is determined according to duration bands comprising: 5% discount for duration of 3 to 6 months, 10% discount for duration of 7 to 12 months, and 15% discount for duration greater than 12 months.

5. The system as claimed in claim 1, wherein said payment validation program identifies duplicate transactions by maintaining an in-memory hash or lookup table of processed transaction identifiers during batch execution.

6. The system as claimed in claim 1, wherein said exception dataset records include a source step identifier, a failing record key, an alphanumeric error classification code, an error description string, and an execution timestamp.

7. A computer-implemented batch processing method executed on an enterprise mainframe, comprising:
   - allocating and initializing master and working datasets via a job control language (JCL) utility step;
   - executing a compiled validation program to validate customer account standing, subscription validity, plan status, and billing due dates;
   - diverting invalid or inactive records to a sequential exception dataset while writing valid subscription records to an intermediate dataset;
   - executing a compiled billing program conditioned upon a successful return code of said validation program to calculate duration-tiered discounts and tax to generate final bills;
   - executing a compiled payment reconciliation program to match payment transactions against said generated final bills and route failed payments, partial payment mismatches, and duplicate transactions to said sequential exception dataset;
   - aggregating financial totals by subscription plan into a revenue dataset; and
   - generating print-formatted spool reports comprising a billing register, a revenue summary, and an exception rejection log.

8. The method as claimed in claim 7, wherein said billing program calculates the final bill amount ($F$) according to:
   $$F = \left[B \times \left(1 - \frac{D}{100}\right)\right] \times (1 + T)$$
   where $B$ is plan base amount, $D$ is duration discount percentage, and $T$ is tax rate.

9. The method as claimed in claim 7, wherein said batch processing method maintains dataset disposition integrity across job steps using JCL `DISP` parameters, ensuring dataset allocation on job step initiation and scratch dataset purging upon step completion.

10. A non-transitory computer-readable storage medium comprising instructions that, when executed by one or more processors of a mainframe computing system, cause the processors to execute the batch processing method of claim 7.

---

### 12. ABSTRACT
The present invention discloses a mainframe-based, computer-implemented system and method for automated recurring subscription billing, payment validation, and revenue reporting. A Job Control Language (JCL) batch job orchestrates sequenced execution of a validation program (`SUBVAL`), a billing program (`BILLPROC`), a payment reconciliation program (`PAYPROC`), a revenue aggregation program (`REVPROC`), and a reporting program (`REPORT`) operating on VSAM KSDS and sequential datasets. The validation program verifies customer, subscription, and plan status, diverting non-conforming records to an exception dataset while permitting valid records to proceed. The billing program computes duration-tiered discounts and statutory taxes to calculate final bills. The payment program classifies incoming transactions as successful, amount mismatch, failed, or duplicate, routing non-success transactions to the exception dataset. The revenue and reporting programs compute aggregate receivables and spool official billing, revenue, and exception registers under return-code-controlled batch safety.

---
*(Applicants & Inventors Signatures)*
*(Vishwakarma Institute of Technology & Vishwakarma University, Pune)*
