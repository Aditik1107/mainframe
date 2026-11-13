# IBM Z Enterprise Mainframe: VS Code, Vista TN3270 & RACF Security Guide

> **Project:** *A Mainframe-Based Automated Batch System and Method for Subscription Billing, Payment Validation and Revenue Reporting*  
> **Applicants:** Vishwakarma Institute of Technology (VIT), Pune & Vishwakarma University (VU), Pune  
> **Inventors:** Prof. Madhura Sanap, Aditi Prakash Kadam, Sharayu Abhijit Itkikar, Smruti Babruwan Gadave  

---

## 📌 Executive Summary: "Shifting to Vista in VS Code"

In enterprise mainframe environments and university computer labs, **two common contexts** surround the phrase *"shift the project to vista in VS Code"*:

### 1. The Mainframe Perspective: Vista TN3270 vs. Modern VS Code
* **What is Vista?** In mainframe education, **Vista** refers to **Vista TN3270 Terminal Emulator** (by Tom Brennan Software). For decades, it has been the standard Windows software used in university mainframe labs to log on to IBM z/OS systems via green-screen 3270 terminals.
* **Why the shift to VS Code?** The global mainframe industry (led by IBM, Broadcom, and the Open Mainframe Project) has modernized developer workflows by shifting from standalone 3270 terminal emulators into **Visual Studio Code**.
* **How this project supports it:**
  - **In-Editor 3270 Terminal:** With the recommended `tomasdanek.tn3270` extension, developers can run an authentic 3270 terminal tab directly inside VS Code.
  - **Language Tooling:** Pre-configured with **Broadcom Code4z** (`cobol-language-support` and `jcl-language-support`) with column-alignment rulers for 80-column punch-card COBOL formatting (columns 1-6 sequence, 7 indicator, 8-11 Area A, 12-72 Area B).
  - **One-Click Execution:** Full `.vscode/launch.json` and `.vscode/tasks.json` allowing you to press **F5** to debug the system or **Ctrl+Shift+B** to submit master batch job `SUBBILL01` and recompile COBOL sources using GnuCOBOL (`cobc`).

### 2. The Frontend Tooling Perspective: Vite in VS Code
* If your professor or guide meant **Vite** (pronounced */veet/*, frequently misheard/autocorrected as *"Vista"*):
  - The project includes a pre-configured Vite development environment in `frontend/` (`package.json`, `vite.config.js`).
  - You can run `npm run dev` directly in VS Code's integrated terminal or via the built-in VS Code task **"Frontend: Start Vite Dev Server (Port 3000)"**.
  - All API calls are transparently proxied to the FastAPI backend on port `8000`.

---

## 🔐 Enterprise Security Architecture: IBM z/OS RACF & SMF Type 80

The system implements a production-grade security subsystem modeled after IBM's **RACF (Resource Access Control Facility)** on z/Architecture, backed by **SMF (System Management Facility) Type 80** security event auditing.

```
+-----------------------------------------------------------------------------------+
|                           IBM z/OS RACF SECURITY ENGINE                           |
+-----------------------------------------------------------------------------------+
|  [ RACF User Registry ]                                                           |
|    - SYSADMIN (SYS1)     -> System Programmer & Batch Operator (Full Authority)   |
|    - BILLMGR  (FINGRP)   -> Billing & Revenue Supervisor (Ledgers & Reports)      |
|    - DATAOPR  (OPSGRP)   -> Operations Data Clerk (Master Datasets CRUD)          |
|    - AUDITOR  (AUDITGRP) -> Regulatory Compliance Auditor (Strictly Read-Only)    |
+-----------------------------------------------------------------------------------+
|  [ Cryptographic Engine ]                                                         |
|    - Salted PBKDF2-HMAC-SHA256 Password Hashing (100,000 rounds)                 |
|    - Signed HMAC-SHA256 Bearer Tokens with Cryptographic Nonce & 8h Expiry        |
|    - Active Token Revocation / Blacklist on Logoff                               |
+-----------------------------------------------------------------------------------+
|  [ Active Defense & SMF80 Audit ]                                                 |
|    - Brute Force Lockout: 5 failed attempts locks user for 300 seconds            |
|    - RBAC Authorization Gates: Raises ICH408I Security Violations on 403 Forbidden|
|    - Immutable Audit Ledger: Persistent logging to data/SECRAUDIT.LOG             |
|    - HTTP Hardening: X-Content-Type-Options, X-Frame-Options, Strict Path Traversal|
+-----------------------------------------------------------------------------------+
```

---

## 👥 Pre-Configured RACF User Credentials

| User ID | Group | Role | Password | Description & Access Rights |
| :--- | :--- | :--- | :--- | :--- |
| **`SYSADMIN`** | `SYS1` | Systems Programmer / Operator | `Pass123!ADMIN` | **Full Authority:** Can execute JCL batch jobs (`SUBBILL01`), trigger step sequencing, wipe/reset VSAM clusters, inject test anomalies, and manage users. |
| **`BILLMGR`** | `FINGRP` | Billing Supervisor | `Pass123!BILL` | **Financial Authority:** Can view records, inspect revenue reconciliations, and export management reports (`BILLRPT.TXT`, `REVRPT.TXT`). Cannot run batch steps or reset datasets. |
| **`DATAOPR`** | `OPSGRP` | Data Operator | `Pass123!DATA` | **Operations Authority:** Can insert/update customer, subscription, and payment records, and resolve exceptions. Cannot purge datasets or execute JCL batch runs. |
| **`AUDITOR`** | `AUDITGRP` | Compliance Inspector | `Pass123!AUDIT` | **Compliance Authority:** Strictly **Read-Only**. Any attempt to mutate data or run batch jobs is intercepted by RACF with an `ICH408I` violation. |

---

## 🛑 RACF Security Violation Example (ICH408I)

When an unauthorized role attempts a restricted action (e.g. `AUDITOR` trying to run master batch job `SUBBILL01`):

```text
HTTP 403 Forbidden
ICH408I USER(AUDITOR) GROUP(AUDITGRP) NAME(RACF SECURITY SUBSYSTEM)
BATCH.SUBBILL01.EXECUTE CL(FACILITY)
INSUFFICIENT ACCESS AUTHORITY - FROM (GENERIC)
ACCESS INTENT(EXECUTE)  ACCESS ALLOWED(NONE)
```

Simultaneously, an **SMF Type 80 Security Audit Record** is written to `data/SECRAUDIT.LOG`:
```text
2026-11-13T08:08:14.123456+00:00|SMF80-00049281|RACF_VIOLATION |AUDITOR   |AUDITGRP|RC=0008|DENIED  |BATCH.SUBBILL01.EXECUTE       |Required roles: ['SYSADMIN'], Actual role: AUDITOR
```

---

## 🛠️ How to Open and Run in VS Code

### Step 1: Open Project in VS Code
```powershell
cd C:\Users\gicsc\OneDrive\Desktop\mainframe
code .
```

### Step 2: Recommended VS Code Extensions
When opened, VS Code will prompt to install recommended extensions (defined in `.vscode/extensions.json`):
1. **TN3270 Terminal** (`tomasdanek.tn3270`): In-editor 3270 terminal emulator.
2. **Broadcom COBOL Language Support** (`broadcom.cobol-language-support`): COBOL syntax & IntelliSense.
3. **Broadcom JCL Language Support** (`broadcom.jcl-language-support`): JCL syntax highlighting.
4. **IBM Zowe Explorer** (`zowe.vscode-extension-for-zowe`): Mainframe datasets and job explorer.
5. **Python** (`ms-python.python`): Python backend debugging.

### Step 3: Run the System
You have multiple easy ways to run the project in VS Code:

* **Option A — Run with F5 (Debugging):**
  1. Press `F5` or click **Run & Debug** in VS Code.
  2. Select **"IBM Z Mainframe: FastAPI & RACF Server"**.
  3. The backend starts on `http://127.0.0.1:8000`.

* **Option B — Run via VS Code Tasks:**
  1. Press `Ctrl+Shift+P` -> Type `Tasks: Run Task`.
  2. Choose:
     - **`Mainframe: Start FastAPI Backend (Port 8000)`** to launch the server.
     - **`Mainframe: Run Master Batch (SUBBILL01)`** (`Ctrl+Shift+B`) to run the batch job directly.
     - **`Mainframe: Recompile All COBOL Programs (cobc)`** to compile all COBOL files with GnuCOBOL.
     - **`Security: Run RACF Automated Test Suite`** to execute the security test suite.

* **Option C — Frontend via Vite:**
  1. Open integrated terminal in VS Code (`Ctrl+\``).
  2. Run:
     ```powershell
     cd frontend
     npm install
     npm run dev
     ```
  3. Open `http://localhost:3000` to interact with the hot-reloading Vite dev server.

---

## 🧪 Testing Security & RACF Roles in the Web Interface

1. Open `http://127.0.0.1:8000` in your browser.
2. The **IBM z/OS RACF LOGON** screen will appear.
3. Try logging in as **`AUDITOR`** (Password: `Pass123!AUDIT`).
4. Click **"Run Billing Cycle Now"**.
5. Observe that the action is instantly blocked with a toast alert:
   > *"Access Denied: ICH408I USER(AUDITOR) GROUP(AUDITGRP)... INSUFFICIENT ACCESS AUTHORITY"*
6. Click the RACF User Badge in the top right to **Logoff**.
7. Log on as **`SYSADMIN`** (Password: `Pass123!ADMIN`).
8. Click **"Run Billing Cycle Now"** — the master batch job completes successfully and all invoices are generated!
9. Click **"SMF80 Audit"** or query `/api/security/audit-log` to view the comprehensive security log detailing every authorized and unauthorized attempt.
