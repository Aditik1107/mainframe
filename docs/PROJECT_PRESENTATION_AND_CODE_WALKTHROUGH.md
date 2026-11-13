# IBM Z Enterprise Mainframe Automated Batch Subscription Billing & Revenue Intelligence System
## Complete Project Presentation Guide & File-by-File Code Walkthrough

> **Patent Title:** *A Mainframe-Based Automated Batch System and Method for Subscription Billing, Payment Validation and Revenue Reporting*  
> **Applicants:** Vishwakarma Institute of Technology (VIT), Pune & Vishwakarma University (VU), Pune  
> **Inventors:** Prof. Madhura Sanap, Aditi Prakash Kadam, Sharayu Abhijit Itkikar, Smruti Babruwan Gadave  
> **Repository:** [https://github.com/Aditik1107/mainframe](https://github.com/Aditik1107/mainframe)  
> **Target Environment:** IBM z/Architecture, z/OS V2R5, MVS JES2, JCL, GnuCOBOL 3.2.0, VSAM KSDS, RACF Security, FastAPI, Three.js WebGL 3D, Vite.

---

## 📑 Table of Contents
1. [Project Elevator Pitch & Core Innovation](#1-project-elevator-pitch--core-innovation)
2. [End-to-End System Architecture (Flow Diagram)](#2-end-to-end-system-architecture)
3. [File-by-File Code Walkthrough](#3-file-by-file-code-walkthrough)
   - [Root Files](#root-files)
   - [COBOL Production Programs (`cobol/`)](#cobol-programs-cobol)
   - [COBOL Copybooks (`copybooks/`)](#cobol-copybooks-copybooks)
   - [Job Control Language (`jcl/`)](#job-control-language-jcl)
   - [Backend & Security Subsystem (`backend/`)](#backend--security-subsystem-backend)
   - [VS Code Workspace Configuration (`.vscode/`)](#vs-code-workspace-configuration-vscode)
   - [Frontend UI & 3D WebGL Visualizer (`frontend/`)](#frontend-ui--3d-webgl-visualizer-frontend)
   - [Python Batch Scripts (`scripts/`)](#python-batch-scripts-scripts)
   - [Datasets & Registers (`data/`)](#datasets--registers-data)
   - [Patent Documentation & Drawings (`docs/`)](#patent-documentation--drawings-docs)
4. [In-Depth Logic of the 5 COBOL Engines](#4-in-depth-logic-of-the-5-cobol-engines)
5. [The RACF Security Subsystem (AuthN, AuthZ & SMF80)](#5-the-racf-security-subsystem)
6. [How the JCL Step Sequencing & Condition Codes Work](#6-how-jcl-step-sequencing--condition-codes-work)
7. [Step-by-Step Presentation Script for Evaluators / Teachers](#7-step-by-step-presentation-script)
8. [Frequently Asked Questions (Viva / Q&A Cheatsheet)](#8-frequently-asked-questions-viva-qa)

---

## 1. Project Elevator Pitch & Core Innovation

Traditional enterprise subscription engines (e.g., Netflix, AWS, Telecoms) process millions of recurring accounts every midnight. In legacy batch systems, if an account encountered a missing customer record, an expired card, or an underpaid bill, either the **entire batch aborted (Abend S0C7 / U4038)** or invalid data contaminated the financial general ledger.

### What Makes This System Novel (Patent-Grade):
1. **Autonomous Non-Fatal Exception Diversion (`RC=0004`):**
   - When defective records are detected in validation (`SUBVAL.cbl`) or payment matching (`PAYPROC.cbl`), the system **isolates them into `EXCEPTION.DAT`** with specific error diagnostic codes, sets condition code `RC=0004`, and **allows all valid customer bills to continue uninterrupted**.
2. **JCL Condition Code Gating (`COND=(4,LT)`):**
   - Step sequencing ensures that non-fatal warning codes (`RC=0004`) do not halt downstream billing, ledger aggregation, or reporting.
3. **Enterprise Mainframe Security (RACF + SMF Type 80):**
   - Full Role-Based Access Control (RBAC) with 4 tiers (`SYSADMIN`, `BILLMGR`, `DATAOPR`, `AUDITOR`), cryptographic HMAC-SHA256 bearer tokens, PBKDF2 password hashing, and immutable SMF Type 80 security event logs.
4. **Modernized Hybrid Interface (3D WebGL + 3270 Spool + Embedded Swagger Docs):**
   - Real-time 3D Three.js hardware cluster showing moving particle bitstreams, dual rotating magnetic tape reels, a live horizontal step timeline scrubber, and an embedded API console directly inside the UI.

---

## 2. End-to-End System Architecture

```text
                               +-----------------------------+
                               |     CUSTMAST.DAT (VSAM)     |
                               |     SUBMAST.DAT  (VSAM)     |
                               |     PLANMAST.DAT (VSAM)     |
                               +--------------+--------------+
                                              |
                                              v
+-----------------------------------------------------------------------------------------+
|                                JCL JOB: SUBBILL01                                       |
+-----------------------------------------------------------------------------------------+
| STEP01: IDCAMS   -> Purge old batch workfiles & reallocate VSAM clusters                |
| STEP02: SUBVAL   -> Validate active customer status, subscription validity, bill dates  |
|                     |--> VALID RECORDS   -> VALIDSUB.DAT                                |
|                     +--> INVALID RECORDS -> EXCEPTION.DAT (RC=0004)                     |
| STEP03: BILLPROC -> Dynamic duration discounting (0%, 5%, 10%, 15%) + 18% GST -> BILLS.DAT |
| STEP04: PAYPROC  -> Match PAYMENT.DAT against BILLS.DAT                                  |
|                     |--> MATCHED (SUCCESS) -> PAYOUT.DAT                                |
|                     +--> MISMATCH / FAIL / DUPLICATE -> EXCEPTION.DAT (RC=0004)         |
| STEP05: REVPROC  -> Aggregate plan-by-plan collected revenue vs receivables -> REVENUE.DAT|
| STEP06: REPORT   -> Spool management registers: BILLRPT.TXT, REVRPT.TXT, EXCPRPT.TXT   |
| STEP07: ARCHIVE  -> Spool dispatch & tape archive logging                               |
+-----------------------------------------------------------------------------------------+
                                              |
                     +------------------------+------------------------+
                     v                                                 v
   +------------------------------------+            +------------------------------------+
   |     FASTAPI & RACF SUBSYSTEM       |            |    INTERACTIVE WEBGL & 3270 UI     |
   | - PBKDF2 Hashing (100k rounds)     |            | - 3D IBM Z Server Racks & 3420 Tape|
   | - Signed HMAC-SHA256 Bearer Tokens | <=======>  | - Authentic Phosphor CRT Terminal  |
   | - SMF Type 80 Audit Logging        |            | - Embedded Live Swagger API Docs   |
   | - Brute-Force Lockout Defense      |            | - 7-Step Interactive Time Scrubber |
   +------------------------------------+            +------------------------------------+
```

---

## 3. File-by-File Code Walkthrough

Here is the exact explanation of every single file in the GitHub repository:

### Root Files

| File | What It Consists Of | Why It Is Important |
| :--- | :--- | :--- |
| **`README.md`** | Complete system documentation, patent inventors, batch step breakdown, and setup instructions. | Acts as the GitHub front-page portfolio and reference manual for evaluators. |
| **`START_MAINFRAME.bat`** | Windows batch script to launch the application. | Verifies MinGW GnuCOBOL environment, starts FastAPI on `127.0.0.1:8000`, and opens the default browser. |
| **`.gitignore`** | Git exclusion rules. | Excludes `__pycache__`, compiled bytecode, `node_modules`, and local OS cache files. |

---

### COBOL Programs (`cobol/`)
All COBOL programs are written in ANSI Enterprise COBOL format (columns 1–6 sequence numbers, column 7 indicator `*`, columns 8–11 Area A, columns 12–72 Area B).

| File | Program ID | What It Consists Of | Mainframe Step |
| :--- | :--- | :--- | :--- |
| **`SUBVAL.cbl`** | `SUBVAL` | Reads `CUSTMAST.DAT`, `SUBMAST.DAT`, and `PLANMAST.DAT`. Validates: 1) Is customer status = `'A'`? 2) Is subscription active? 3) Is bill date due? 4) Does plan ID exist? Diverts failed records to `EXCEPTION.DAT` with code `0004`, writes valid subscriptions to `VALIDSUB.DAT`. | **STEP02** (Validation Gate) |
| **`BILLPROC.cbl`** | `BILLPROC` | Dynamic Pricing Engine. Reads `VALIDSUB.DAT` and `PLANMAST.DAT`. Calculates duration discount based on tiered bands: `<3mo: 0%`, `3-6mo: 5%`, `7-12mo: 10%`, `>12mo: 15%`. Applies statutory 18% GST on net amount. Emits fixed-width records to `BILLS.DAT`. | **STEP03** (Billing Engine) |
| **`PAYPROC.cbl`** | `PAYPROC` | Multi-Rule Payment Reconciliation. Reads `BILLS.DAT` and sequential `PAYMENT.DAT`. Matches transaction amount against bill amount. Classifies into: `SUCCESS`, `AMOUNT MISMATCH`, `FAILED PAYMENT`, or `DUPLICATE TRANSACTION`. Diverts failures to `EXCEPTION.DAT` and matched items to `PAYOUT.DAT`. | **STEP04** (Reconciliation) |
| **`REVPROC.cbl`** | `REVPROC` | Financial Ledger Aggregator. Reads `BILLS.DAT`, `PAYOUT.DAT`, and `PLANMAST.DAT`. Aggregates total billed amount, total cash received, and outstanding receivables per subscription plan and across the enterprise. Emits `REVENUE.DAT`. | **STEP05** (General Ledger) |
| **`REPORT.cbl`** | `REPORT` | Spool Register Generator. Reads output datasets and formats three 132-character line-sequential management reports: `BILLRPT.TXT`, `REVRPT.TXT`, and `EXCPRPT.TXT` with headers, page numbering, totals, and formatted currency. | **STEP06** (Management Spool) |

---

### COBOL Copybooks (`copybooks/`)
Copybooks provide standard data structures included in COBOL programs via the `COPY` statement (equivalent to `#include` in C/C++ or TypeScript interfaces).

| File | Length | Structure & Fields |
| :--- | :--- | :--- |
| **`CUSTREC.cpy`** | 100 Bytes | Customer Master (VSAM KSDS): Customer ID (10), Full Name (30), Email (30), Phone (15), Account Status (1: `'A'`/`'I'`/`'S'`), Registration Date (10), Filler (4). |
| **`SUBREC.cpy`** | 80 Bytes | Subscription Master (VSAM KSDS): Subscription ID (10), Customer ID (10), Plan ID (8), Start Date (10), End Date (10), Duration Months (3: `999`), Status (1), Next Bill Date (10), Filler (18). |
| **`PLANREC.cpy`** | 60 Bytes | Plan Master (VSAM KSDS): Plan ID (8), Plan Name (25), Monthly Base Amount (9: `PIC 9(7)V99`), Billing Cycle (1: `'M'`/`'Q'`/`'Y'`), Status (1), Filler (16). |
| **`PAYREC.cpy`** | 80 Bytes | Payment Input (Sequential): Transaction ID (12), Subscription ID (10), Payment Amount (9: `PIC 9(7)V99`), Transaction Date (10), Payment Mode (15: UPI/Card), Status (10), Filler (14). |
| **`VALIDSUB.cpy`**| 80 Bytes | Validated Subscriptions passed from `SUBVAL` to `BILLPROC`. |
| **`BILLREC.cpy`** | 100 Bytes | Calculated Invoices: Bill ID (12), Subscription ID (10), Customer ID (10), Plan ID (8), Base Amount (9), Discount Pct (4), Discount Amt (9), Tax Amt (9), Final Bill Amt (9), Bill Date (10), Filler (10). |
| **`PAYOUTREC.cpy`**| 80 Bytes | Reconciled Payouts: Transaction ID (12), Bill ID (12), Subscription ID (10), Amount (9), Payment Date (10), Payment Mode (15), Match Status (10). |
| **`REVREC.cpy`**  | 80 Bytes | Revenue Summary: Plan ID (8), Plan Name (25), Subscriber Count (5), Billed Amount (11), Received Amount (11), Outstanding Receivables (11), Filler (9). |
| **`EXCPREC.cpy`** | 80 Bytes | Exception Record: Source Job Step (8), Record Key (15), Error Code (10), Error Description (30), Timestamp (17). |

---

### Job Control Language (`jcl/`)

| File | What It Consists Of | Why It Is Important |
| :--- | :--- | :--- |
| **`SUBBILL01.jcl`** | Master MVS JES2 Job Stream. Defines job card `//SUBBILL01 JOB (ACCT),'BILLING BATCH',CLASS=A,MSGCLASS=X`. Sequences 7 job steps (`STEP01` IDCAMS, `STEP02` SUBVAL, `STEP03` BILLPROC, `STEP04` PAYPROC, `STEP05` REVPROC, `STEP06` REPORT, `STEP07` DISPATCH) with `COND=(4,LT)` return-code gating and DD statements mapping datasets. | The central mainframe orchestration script that coordinates datasets and executables. |
| **`IDCAMS.jcl`** | IBM Access Method Services script (`IDCAMS`). Defines, deletes, and allocates VSAM KSDS clusters and linear datasets with primary/secondary track extents (`CYL(5,1)`). | Ensures clean workspace allocation before every batch run. |

---

### Backend & Security Subsystem (`backend/`)

| File | What It Consists Of | Key Responsibilities |
| :--- | :--- | :--- |
| **`backend/security.py`** | **IBM RACF Enterprise Security Subsystem:**<br>• RACF User Registry (`SYSADMIN`, `BILLMGR`, `DATAOPR`, `AUDITOR`).<br>• PBKDF2-HMAC-SHA256 password hashing (100,000 rounds).<br>• Signed HMAC-SHA256 bearer tokens with 8-hour expiry and token revocation blacklist.<br>• Brute-force protection (5 failed logins locks account for 300 seconds).<br>• SMF Type 80 Security Audit Logger (`data/SECRAUDIT.LOG`).<br>• RACF Violation Message Formatter (`ICH408I`). | Implements enterprise-grade authentication, authorization, and auditability required by enterprise banks and patent examiners. |
| **`backend/server.py`** | **FastAPI Enterprise Server (35 Endpoints):**<br>• Batch execution APIs (`/api/batch/run`, `/api/batch/step/{step_id}`).<br>• RACF Authentication APIs (`/api/auth/login`, `/api/auth/logout`, `/api/auth/me`, `/api/auth/users`).<br>• Dataset CRUD APIs with fixed-width VSAM parsers.<br>• Anomaly injection & remediation APIs (`/api/datasets/inject`, `/api/datasets/fix-exception`).<br>• Security audit & stats APIs (`/api/security/audit-log`, `/api/security/stats`).<br>• Reports and source code catalog APIs.<br>• HTTP Security Headers middleware (`X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN`, `X-XSS-Protection`, `Referrer-Policy`). | Acts as the middleware connecting modern Web/REST clients to underlying COBOL compiled executables and datasets. |

---

### VS Code Workspace Configuration (`.vscode/`)

| File | What It Consists Of | Why It Matters |
| :--- | :--- | :--- |
| **`.vscode/launch.json`** | Debug and run profiles for FastAPI server, batch runner, and dataset generator. | Allows 1-click **`F5`** execution in VS Code without manually opening terminal windows. |
| **`.vscode/tasks.json`** | Build tasks: 1) Run Master Batch `SUBBILL01` (**`Ctrl+Shift+B`**), 2) Recompile all COBOL files with `cobc`, 3) Start Vite dev server, 4) Run RACF test suite. | Replaces legacy standalone compilation tools with native VS Code tasks. |
| **`.vscode/settings.json`** | File associations (`.cbl`, `.cpy`, `.jcl`) and column rulers: `[6, 7, 11, 72, 80]`. | Enforces standard 80-column punched-card formatting required by IBM mainframe compilers. |
| **`.vscode/extensions.json`** | Recommends: Broadcom COBOL, Broadcom JCL, TN3270 Terminal, Zowe Explorer, Python, Vite. | Installs modern mainframe developer tooling automatically on any machine. |

---

### Frontend UI & 3D WebGL Visualizer (`frontend/`)

| File | What It Consists Of |
| :--- | :--- |
| **`frontend/index.html`** | **Complete Single Page Application (SPA):**<br>• **Tab 1 — Billing Cycle:** One-click execution button, 5-stage pipeline progress cards, live execution metrics, and real-time defect isolation alerts.<br>• **Tab 2 — Calculator & Lab:** Interactive pricing simulator (duration bands, GST rate) and 1-click anomaly injector.<br>• **Tab 3 — Records:** Master dataset manager for Customers, Subscriptions, Plans, and Payments with search, add, delete, and CSV export.<br>• **Tab 4 — Reports:** Line-sequential CRT viewer for `BILLRPT.TXT`, `REVRPT.TXT`, and `EXCPRPT.TXT`.<br>• **Tab 5 — 3D Model:** Full Three.js 3D cluster with glowing data highway, rotating magnetic tapes (IBM 3420), server racks, and a 7-step horizontal timeline scrubber.<br>• **Tab 6 — API Docs:** Live interactive API explorer with "Send Call" console and embedded FastAPI Swagger UI.<br>• **RACF Security Dialog:** Logon modal with 1-click credential auto-fill, active user badge, and logoff trigger.<br>• **AI Voice Assistant:** Audio walkthrough using browser SpeechSynthesis. |
| **`frontend/package.json`** | NPM configuration for Vite, React, Three.js, Lucide-React, TailwindCSS, and Autoprefixer. |
| **`frontend/vite.config.js`** | Vite dev server configuration proxying `/api` requests to backend port `8000`. |
| **`frontend/tailwind.config.js`** | Tailwind CSS custom theme defining Warm Ivory (`#FAF7F2`), Emerald Green (`#059669`), and Vermilion (`#E34234`). |

---

### Python Batch Scripts (`scripts/`)

| File | What It Consists Of |
| :--- | :--- |
| **`scripts/run_batch.py`** | MVS JES2 Batch Initiator emulator. Simulates Job `SUBBILL01` execution: purges workfiles (STEP01), sequentially invokes compiled binaries (`SUBVAL.exe`, `BILLPROC.exe`, `PAYPROC.exe`, `REVPROC.exe`, `REPORT.exe`), logs condition codes (`RC=0000`/`RC=0004`), and produces JES2 spool output. |
| **`scripts/generate_data.py`** | Factory master data generator. Generates 10 realistic customers, 10 subscriptions, 4 plans, and 10 payment transactions in fixed-width byte alignments. |
| **`scripts/verify_ui.py`** | Automated validation script that executes batch runs and verifies that generated reports match calculated math. |

---

### Datasets & Registers (`data/`)

| File | Format | Contents |
| :--- | :--- | :--- |
| **`CUSTMAST.DAT`** | Fixed-width (100B) | Customer Master VSAM KSDS dataset. |
| **`SUBMAST.DAT`** | Fixed-width (80B) | Subscription Master VSAM KSDS dataset. |
| **`PLANMAST.DAT`** | Fixed-width (60B) | Plan Master VSAM KSDS dataset. |
| **`PAYMENT.DAT`** | Fixed-width (80B) | Sequential payment transactions received from payment gateways. |
| **`VALIDSUB.DAT`** | Fixed-width (80B) | Validated subscriptions output from STEP02. |
| **`BILLS.DAT`** | Fixed-width (100B) | Invoices generated by STEP03 with discount and tax calculations. |
| **`PAYOUT.DAT`** | Fixed-width (80B) | Reconciled matched payments from STEP04. |
| **`REVENUE.DAT`** | Fixed-width (80B) | Plan-wise revenue aggregations from STEP05. |
| **`EXCEPTION.DAT`** | Fixed-width (80B) | Isolated defect records diverted by STEP02 and STEP04. |
| **`BILLRPT.TXT`** | Line Sequential (132B) | Formal Billing Management Register. |
| **`REVRPT.TXT`** | Line Sequential (132B) | Revenue and Collections Register. |
| **`EXCPRPT.TXT`** | Line Sequential (132B) | Exception Audit Register. |
| **`SECRAUDIT.LOG`** | Pipe-delimited | Immutable SMF Type 80 Security Event Audit Trail. |

---

### Patent Documentation & Drawings (`docs/`)

| File | Description |
| :--- | :--- |
| **`Patent_Specification_Complete.md`** | Complete legal patent application specification with Claims (1–10), Abstract, Technical Field, Background, Detailed Description, and Inventive Steps. |
| **`VISTA_VSCODE_GUIDE.md`** | Comprehensive explanation of shifting from Vista TN3270 to modern VS Code with RACF security setup. |
| **`docs/drawings/FIG1_System_Architecture.png`** | Patent Figure 1: Overall System Architecture (Reference numerals 100–160). |
| **`docs/drawings/FIG2_Batch_Execution_Flow.png`** | Patent Figure 2: Batch Execution & Non-Fatal Exception Diversion Flow (201–209). |
| **`docs/drawings/FIG3_Dataset_File_Operations.png`** | Patent Figure 3: VSAM KSDS and Sequential File Operations across job steps. |
| **`docs/drawings/FIG4_Validation_Billing_Payment_Rules.png`** | Patent Figure 4: Duration Discount Tiers, Tax Math, and Reconciliation Decision Matrix. |

---

## 4. In-Depth Logic of the 5 COBOL Engines

### Program 1: `SUBVAL.cbl` (Validation Gate)
* **Goal:** Filter corrupted, inactive, or expired accounts before calculating bills.
* **Logic:**
  1. Reads `SUBMAST.DAT`. For each record, queries `CUSTMAST.DAT` by Customer ID.
  2. If customer status is not `'A'` (e.g. `'I'` = Inactive, `'S'` = Suspended), diverts to `EXCEPTION.DAT` with code `ERR-CUST-INACTIVE`.
  3. Checks subscription end date vs. next bill date. If expired, diverts with code `ERR-SUB-EXPIRED`.
  4. Verifies plan existence in `PLANMAST.DAT`. If missing, diverts with code `ERR-PLAN-INVALID`.
  5. If valid, writes to `VALIDSUB.DAT`.
  6. If any record was diverted, returns condition code **`RETURN-CODE = 0004`** (Warning, continue job).

### Program 2: `BILLPROC.cbl` (Dynamic Billing Engine)
* **Goal:** Calculate duration-based volume discounts and statutory GST.
* **Pricing Rules:**
  $$\text{Discount Rate} = \begin{cases} 
  0\% & \text{if duration} < 3 \text{ months} \\
  5\% & \text{if } 3 \le \text{duration} \le 6 \text{ months} \\
  10\% & \text{if } 7 \le \text{duration} \le 12 \text{ months} \\
  15\% & \text{if duration} > 12 \text{ months}
  \end{cases}$$
* **Mathematical Formula:**
  $$\text{Discount Amount} = \text{Base Amount} \times \text{Discount Rate}$$
  $$\text{Net Amount} = \text{Base Amount} - \text{Discount Amount}$$
  $$\text{Tax Amount (18\% GST)} = \text{Net Amount} \times 0.18$$
  $$\text{Final Bill Amount} = \text{Net Amount} + \text{Tax Amount}$$
* Outputs calculated records to `BILLS.DAT`.

### Program 3: `PAYPROC.cbl` (Payment Matching & Reconciliation)
* **Goal:** Verify incoming transaction records against calculated invoices.
* **Matching Matrix:**
  1. Matches incoming `PAYMENT.DAT` against `BILLS.DAT` by `SUB-ID`.
  2. If transaction status is `'FAILED'`, diverts to `EXCEPTION.DAT` with code `ERR-PAY-FAILED`.
  3. If payment amount $\ne$ billed amount, diverts with code `ERR-AMT-MISMATCH`.
  4. Checks duplicate transaction IDs. If already processed, diverts with code `ERR-DUP-TXN`.
  5. If all checks pass, writes to `PAYOUT.DAT` with status `'MATCHED'`.

### Program 4: `REVPROC.cbl` (Revenue Ledger Aggregation)
* **Goal:** Financial reconciliation by plan.
* **Aggregations:**
  - $\text{Total Billed} = \sum \text{BILLS.DAT}$
  - $\text{Total Received} = \sum \text{PAYOUT.DAT}$
  - $\text{Outstanding Receivables} = \text{Total Billed} - \text{Total Received}$
* Groups by `PLAN-001` (Basic), `PLAN-002` (Standard), `PLAN-003` (Premium), `PLAN-004` (Enterprise), and enterprise grand total. Outputs `REVENUE.DAT`.

### Program 5: `REPORT.cbl` (Print Register Formatter)
* **Goal:** Format standardized management spool output registers.
* Outputs:
  1. `BILLRPT.TXT`: Line-by-line invoice statements with customer names and discount breakdowns.
  2. `REVRPT.TXT`: Income summary showing billed vs. received revenue and collection percentages.
  3. `EXCPRPT.TXT`: Complete audit log of every diverted defect record, showing source step and cause.

---

## 5. The RACF Security Subsystem

The backend implements an enterprise-grade security architecture modeled after **IBM RACF (Resource Access Control Facility)**:

### 1. User Profiles & Role-Based Access Control (RBAC)

| User ID | Group | Assigned Role | Permissions |
| :--- | :--- | :--- | :--- |
| **`SYSADMIN`** | `SYS1` | Systems Programmer | `batch:run`, `batch:step`, `datasets:crud`, `datasets:reset`, `datasets:inject`, `reports:read`, `audit:read`, `security:manage` |
| **`BILLMGR`** | `FINGRP` | Billing Supervisor | `reports:read`, `datasets:read`, `audit:read`, `revenue:export` |
| **`DATAOPR`** | `OPSGRP` | Operations Clerk | `datasets:read`, `datasets:crud`, `reports:read` |
| **`AUDITOR`** | `AUDITGRP`| Compliance Auditor | `datasets:read`, `reports:read`, `audit:read` (**Strictly Read-Only**) |

### 2. Cryptographic Security Standards
* **PBKDF2-HMAC-SHA256**: Passwords stored with random cryptographic salts and 100,000 hash iterations.
* **Signed HMAC-SHA256 Tokens**: High-entropy session tokens with 8-hour expiry and unique nonces (`jti`).
* **Active Token Revocation**: Logout actively invalidates tokens in a server-side revocation blacklist.
* **Brute-Force & Lockout Defense**: 5 consecutive incorrect attempts automatically locks out the account for 300 seconds.
* **SMF Type 80 Security Audit Trail**: Every authentication attempt, RACF violation, dataset mutation, and batch execution is permanently appended to `data/SECRAUDIT.LOG`.

---

## 6. How JCL Step Sequencing & Condition Codes Work

In IBM z/OS, job step execution is controlled by return codes:
* `RC = 0000`: Normal successful execution.
* `RC = 0004`: Non-fatal warning / exception diverted (data isolated to `EXCEPTION.DAT`).
* `RC = 0008`+: Critical error.

In `SUBBILL01.jcl`, every step includes:
```jcl
//STEP03   EXEC PGM=BILLPROC,COND=(4,LT)
```
### What `COND=(4,LT)` Means:
`COND=(4,LT)` reads as: *"Bypass this step if 4 is LESS THAN the return code of any previous step."*
* If previous step returned `RC=0000`: Is $4 < 0$? **False** $\rightarrow$ Step executes.
* If previous step returned `RC=0004`: Is $4 < 4$? **False** $\rightarrow$ Step executes! (Non-fatal exceptions do not halt the batch).
* If previous step returned `RC=0008`: Is $4 < 8$? **True** $\rightarrow$ Step is bypassed to prevent cascade corruption.

This is the core patented mechanism of the project.

---

## 7. Step-by-Step Presentation Script

Follow this script during your college viva or project presentation:

### Phase 1: Introduction (1 Minute)
> *"Respected teachers and panel members, our project is titled **'A Mainframe-Based Automated Batch System and Method for Subscription Billing, Payment Validation and Revenue Reporting'**, filed as a patent by VIT and VU Pune under inventors Prof. Madhura Sanap, Aditi Kadam, Sharayu Itkikar, and Smruti Gadave."*
>
> *"Our project addresses a major problem in enterprise billing: in traditional batch processing, a single invalid customer or failed payment transaction can abort an entire midnight batch run. We have designed an autonomous non-fatal exception diversion architecture orchestrated via JCL and 5 compiled COBOL engines."*

### Phase 2: Live Demonstration (2 Minutes)
1. **Show the Web UI at `http://127.0.0.1:8000`:**
   > *"Notice our modern command center. When you open the application, you are greeted by an IBM z/OS RACF Logon screen. All operations are role-governed."*
2. **Demonstrate RACF Authorization:**
   > *"Let us log on as `AUDITOR`. If the auditor attempts to click 'Run Billing Cycle Now', the system rejects it with an authentic `403 Forbidden` RACF violation message: `ICH408I INSUFFICIENT ACCESS AUTHORITY`. This prevents unauthorized batch executions."*
3. **Log on as `SYSADMIN` and Execute Master Batch:**
   > *"Now let us log on as `SYSADMIN`. We hit 'Run Billing Cycle Now'. Notice how the 5-stage progress bar executes in sequence. In under 1 second, the system validated subscriptions, applied duration discounts and GST, reconciled incoming payments, aggregated the revenue ledger, and produced spool reports."*
4. **Show Exception Diversion:**
   > *"Notice that out of 10 incoming subscriptions, 6 valid invoices were created, while 4 defective records were autonomously diverted to `EXCEPTION.DAT` with return code `RC=0004`. The batch did not crash!"*
5. **Show the 3D Hardware Model & CRT Terminal:**
   > *"In the '3D Model' tab, you can see our Three.js IBM Z hardware cluster. Green particle highways represent valid records flowing through, while red beams shoot exceptions into the isolation silo. You can drag the 7-step horizontal timeline scrubber to seek camera angles and inspect any step."*
6. **Show Embedded API Documentation:**
   > *"In the 'API Docs' tab, we have embedded an interactive REST API explorer and live Swagger UI directly into the application. Evaluators can test all 29 endpoints interactively using live RACF tokens."*

### Phase 3: VS Code & Modernization (1 Minute)
> *"As recommended, we have completely shifted the project from legacy standalone Vista software into VS Code. By pressing **F5** in VS Code, the server boots up; by pressing **Ctrl+Shift+B**, all COBOL programs are recompiled with GnuCOBOL and the batch job runs. We have also configured Broadcom COBOL/JCL language support with 80-column punch-card rulers and the in-editor TN3270 terminal emulator."*

---

## 8. Frequently Asked Questions (Viva / Q&A)

### Q1: Why use COBOL and Mainframe instead of Python or Java for billing?
**Answer:** Enterprise mainframes handle over 70% of global financial transactions. COBOL's fixed-point decimal arithmetic (`PIC 9(7)V99`) guarantees zero binary rounding errors, unlike floating-point math in Python or JavaScript which causes rounding discrepancies in multi-million dollar ledgers.

### Q2: What is the difference between VSAM KSDS and Sequential files?
**Answer:** A Sequential file (`PAYMENT.DAT`) is read from beginning to end in order. A VSAM KSDS (Key Sequenced Data Set, such as `CUSTMAST.DAT` and `SUBMAST.DAT`) allows instantaneous random lookup by primary key (Customer ID or Subscription ID) using an embedded B-tree index, making validation instantaneous.

### Q3: How do you prevent SQL injection or path traversal attacks?
**Answer:** The API uses strict whitelist regex validation (`^[A-Za-z0-9_\-\.]+$`) on all file paths and dataset targets, rejecting any `../` directory traversal attempts with HTTP 400. In addition, all mutations are gated by RACF role dependencies.

### Q4: What is an SMF Type 80 record?
**Answer:** In IBM z/OS, System Management Facility (SMF) logs system activity. Type 80 records specifically log security events generated by RACF, including user logons, unauthorized access attempts, and resource modifications. Our system persists these to `data/SECRAUDIT.LOG`.

### Q5: How is this patentable?
**Answer:** The patent claims the specific combination of:
1. Automated non-fatal step sequencing using return-code gating (`COND=(4,LT)`).
2. Dynamic multi-tier duration discount math with automated tax compounding in COBOL.
3. Multi-rule reconciliation that classifies payment defects into distinct exception classes without job abortion.
4. Interactive dual-mode visual synchronization between WebGL 3D bitstreams, CRT terminals, and live mainframe datasets.
