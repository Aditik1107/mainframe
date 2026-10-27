# IBM Z Enterprise Mainframe Automated Batch Subscription Billing, Payment Validation & Revenue Reporting System

> **Patent Title:** *A Mainframe-Based Automated Batch System and Method for Subscription Billing, Payment Validation and Revenue Reporting*  
> **Applicants:** Vishwakarma Institute of Technology (VIT), Pune & Vishwakarma University (VU), Pune  
> **Inventors:** Prof. Madhura Sanap, Aditi Prakash Kadam, Sharayu Abhijit Itkikar, Smruti Babruwan Gadave  
> **Environment:** IBM z/Architecture, MVS JES2, Job Control Language (JCL), GnuCOBOL 3.2.0, VSAM KSDS, Three.js WebGL 3D, FastAPI

---

## 🌟 Overview & Technical Highlights

This project implements a complete, end-to-end enterprise mainframe batch architecture for recurring subscription billing and multi-rule financial reconciliation, paired with a futuristic 3D WebGL Command Center.

### Key Mainframe Innovations:
1. **JCL-Orchestrated Step Sequencing (`SUBBILL01.jcl`):**
   - Sequenced batch execution across 7 job steps (`STEP01` to `STEP07`).
   - Condition-controlled execution (`COND=(4,LT)`) ensuring job step progression without halting when non-fatal warnings or data exceptions occur.
2. **5 Compiled COBOL Programs (`cobol/` & `bin/`):**
   - **`SUBVAL.cbl` (STEP02):** Validates customer account status, subscription validity, plan entitlements, and due dates. Diverts defective records to `EXCEPTION.DAT` (`RC=0004`) while forwarding valid subscriptions to `VALIDSUB.DAT`.
   - **`BILLPROC.cbl` (STEP03):** Dynamic pricing engine calculating duration-based discount bands (3–6 mo: 5%, 7–12 mo: 10%, >12 mo: 15%) and 18% statutory tax on net base to generate `BILLS.DAT`.
   - **`PAYPROC.cbl` (STEP04):** Payment reconciliation engine matching transactions against bills and classifying into: `SUCCESS`, `AMOUNT MISMATCH`, `FAILED PAYMENT`, or `DUPLICATE TRANSACTION`.
   - **`REVPROC.cbl` (STEP05):** Revenue ledger aggregating billed, collected, and outstanding receivables by plan and in total (`REVENUE.DAT`).
   - **`REPORT.cbl` (STEP06):** Spools three standardized management print registers: `BILLRPT.TXT`, `REVRPT.TXT`, and `EXCPRPT.TXT`.
3. **Interactive 3D WebGL Frontend (`frontend/index.html`):**
   - **3D Mainframe Racks:** IBM Z-style server cabinets with blinking status LED matrices.
   - **3D Tape Subsystem:** Rotating dual magnetic reels (IBM 3420) that accelerate with batch workload.
   - **Moving Bits & Glowing Data Highways:** Particle stream representing records traveling along pipelines with glowing cyan/green paths for valid items and a red beam shooting exceptions into the `EXCEPTION.DAT` isolation silo.
   - **Innovative Horizontal Slider (Step Scrubber):** Interactive 7-step timeline placed at the top or bottom with step seeking, camera focal tracking, execution metrics, and play/pause controls.
   - **IBM 3270 CRT Spool Terminal:** Authentic phosphor green-screen CRT display showing live JES2 job logs.
   - **Dataset Explorer & Defect Injector:** Test edge cases (inactive subscriber, partial payment, duplicate transaction) and witness autonomous mainframe diversion in real time.

---

## 📁 Repository Structure

```text
mainframe/
├── cobol/                              # Production COBOL Processing Programs
│   ├── SUBVAL.cbl                      # STEP02: Validation Program
│   ├── BILLPROC.cbl                    # STEP03: Billing Calculation Engine
│   ├── PAYPROC.cbl                     # STEP04: Payment Reconciliation Program
│   ├── REVPROC.cbl                     # STEP05: Revenue Aggregation Program
│   └── REPORT.cbl                      # STEP06: Spool Print Report Generator
├── copybooks/                          # COBOL Data Structure Definitions
│   ├── CUSTREC.cpy                     # Customer Master (VSAM KSDS, 100 bytes)
│   ├── SUBREC.cpy                      # Subscription Master (VSAM KSDS, 80 bytes)
│   ├── PLANREC.cpy                     # Plan Master (VSAM KSDS, 60 bytes)
│   ├── PAYREC.cpy                      # Payment Input (Sequential, 80 bytes)
│   ├── VALIDSUB.cpy                    # Validated Subscriptions (80 bytes)
│   ├── BILLREC.cpy                     # Calculated Bills (100 bytes)
│   ├── PAYOUTREC.cpy                   # Verified Payments (80 bytes)
│   ├── REVREC.cpy                      # Revenue Summary (80 bytes)
│   └── EXCPREC.cpy                     # Exception Rejection Log (100 bytes)
├── jcl/                                # Job Control Language Scripts
│   ├── SUBBILL01.jcl                   # Master Production Batch Job
│   └── IDCAMS.jcl                      # VSAM KSDS Cluster Definitions & Catalog
├── data/                               # VSAM KSDS & Sequential Datasets
│   ├── CUSTMAST.DAT                    # Customer Master (Key: CUST-ID)
│   ├── SUBMAST.DAT                     # Subscription Master (Key: SUB-ID)
│   ├── PLANMAST.DAT                    # Plan Master (Key: PLAN-ID)
│   ├── PAYMENT.DAT                     # Payment Input Transactions
│   ├── BILLRPT.TXT                     # Detailed Billing Register (Spool)
│   ├── REVRPT.TXT                      # Executive Revenue Summary (Spool)
│   └── EXCPRPT.TXT                     # Exception & Rejection Audit Log (Spool)
├── bin/                                # Compiled COBOL Executables (.exe)
├── scripts/
│   ├── run_batch.py                    # Mainframe Batch Initiator & JES2 Emulator
│   ├── generate_data.py                # Master Dataset Seed Generator
│   └── compile_all.py                  # GnuCOBOL Batch Compiler
├── backend/
│   └── server.py                       # FastAPI Server & REST API Gateway
├── frontend/
│   └── index.html                      # Interactive 3D WebGL & Slider Command Center
├── docs/                               # Official Patent Documents & Figures
│   ├── Patent_Specification_Complete.md # Form 2 Complete Specification
│   └── drawings/                       # Official Patent Figures (FIG. 1 to FIG. 4)
└── START_MAINFRAME.bat                 # One-click system launcher
```

---

## 🚀 How to Run

### Method 1: One-Click Launcher (Windows)
Double-click [`START_MAINFRAME.bat`](file:///c:/Users/gicsc/OneDrive/Desktop/mainframe/START_MAINFRAME.bat).  
It will set up the compiler path, launch the backend server on `http://127.0.0.1:8000`, and open the 3D Command Center in your default browser.

### Method 2: Manual Command Line
```powershell
# 1. Navigate to project root
cd c:\Users\gicsc\OneDrive\Desktop\mainframe

# 2. Run the Mainframe Batch Engine directly
python scripts/run_batch.py

# 3. Launch the Web API & 3D Visualizer
python -m uvicorn backend.server:app --host 127.0.0.1 --port 8000 --reload
```
Open **[http://127.0.0.1:8000](http://127.0.0.1:8000)** in your web browser.

---

## 📊 Sample Batch Results (Job SUBBILL01)

### Detailed Billing Register (`BILLRPT.TXT`)
```text
========================================================================================================================
MAINFRAME SUBSCRIPTION BILLING SYSTEM (JOB SUBBILL01)               REPORT: BILLRPT - DETAILED BILLING REGISTER
RUN DATE: 2026-10-19                                                       PAGE: 0001 DETAILED BILLING REGISTER
========================================================================================================================
BILL ID       SUB ID      CUST ID     PLAN      BASE AMT    DISC %    DISC AMT     TAX (18%)     FINAL BILL
------------  ----------  ----------  --------  ----------  --------  ----------  ------------  -----------
BIL202610190  SUB1000001  CUST000101  PLAN-001     999.00  10.00%      99.90     161.84    1,060.94
BIL202610190  SUB1000002  CUST000102  PLAN-001     999.00   5.00%      49.95     170.83    1,119.88
BIL202610190  SUB1000003  CUST000103  PLAN-002   4,999.00  15.00%     749.85     764.85    5,014.00
BIL202610190  SUB1000004  CUST000104  PLAN-003     499.00   0.00%       0.00      89.82      588.82
BIL202610190  SUB1000005  CUST000105  PLAN-004   9,999.00  10.00%     999.90   1,619.84   10,618.94
BIL202610190  SUB1000006  CUST000109  PLAN-002   4,999.00  10.00%     499.90     809.84    5,308.94
------------------------------------------------------------------------------------------------------------------------
TOTAL BILLS: 00006          GRAND TOTAL BILLED: $23,711.52
========================================================================================================================
```

### Exception Audit Log (`EXCPRPT.TXT`)
```text
========================================================================================================================
MAINFRAME EXCEPTION AUDIT SYSTEM (JOB SUBBILL01)                    REPORT: EXCPRPT - BATCH EXCEPTION & REJECTION LOG
========================================================================================================================
STEP      RECORD KEY    CODE    FAILURE REASON / EXCEPTION DESCRIPTION       TIMESTAMP
--------  ------------  ------  -------------------------------------------  -------------------
SUBVAL    SUB1000007    ERR001  CUSTOMER IS INACTIVE OR SUSPENDED            2026-10-19 15:48:29
SUBVAL    SUB1000008    ERR003  SUBSCRIPTION STATUS IS NOT ACTIVE            2026-10-19 15:48:29
SUBVAL    SUB1000009    ERR004  PLAN IS RETIRED OR INACTIVE                  2026-10-19 15:48:29
SUBVAL    SUB1000010    ERR001  CUSTOMER IS INACTIVE OR SUSPENDED            2026-10-19 15:48:29
PAYPROC   TXN202610015  ERR013  AMOUNT MISMATCH: PAID LESS THAN BILLED AMT   2026-10-19 15:48:29
PAYPROC   TXN202610016  ERR011  PAYMENT GATEWAY REPORTED TRANSACTION FAILED  2026-10-19 15:48:29
PAYPROC   TXN202610011  ERR010  DUPLICATE TRANSACTION ID DETECTED            2026-10-19 15:48:29
------------------------------------------------------------------------------------------------------------------------
TOTAL EXCEPTION RECORDS DIVERTED: 00007 (BATCH PROCEEDED WITHOUT INTERRUPTION)
========================================================================================================================
```

---

## 📜 Patent Specification
The full Indian Patent Form 2 specification with detailed descriptions, claims 1–10, and inventor signatures is located in [`docs/Patent_Specification_Complete.md`](file:///c:/Users/gicsc/OneDrive/Desktop/mainframe/docs/Patent_Specification_Complete.md).
