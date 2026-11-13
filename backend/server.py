import os
import sys
import re
import csv
import io
import time
import subprocess
from datetime import datetime
from typing import List, Dict, Any, Optional

from fastapi import FastAPI, HTTPException, Request, Depends, Security
from fastapi.responses import Response, FileResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from backend.security import (
    USERS_DB,
    create_access_token,
    verify_token,
    get_current_user,
    get_current_user_optional,
    require_roles,
    check_account_lockout,
    record_failed_attempt,
    record_successful_login,
    verify_password,
    log_smf80_event,
    SECURITY_AUDIT_LOG,
    REVOKED_TOKENS,
    security_bearer
)

app = FastAPI(
    title="IBM Z Enterprise Mainframe Subscription Billing & Security API",
    description="Backend API orchestrating JCL Job SUBBILL01, COBOL programs, VSAM/Sequential datasets, RACF Security Subsystem, and 3D visualizer",
    version="2.0.0"
)

# ----------------- SECURITY HEADERS MIDDLEWARE -----------------
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "SAMEORIGIN"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["X-RACF-Security-Engine"] = "IBM-zOS-RACF-V2.5"
    return response

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(BASE_DIR, "data")
BIN_DIR = os.path.join(BASE_DIR, "bin")
FRONTEND_DIR = os.path.join(BASE_DIR, "frontend")
DOCS_DIR = os.path.join(BASE_DIR, "docs")

def get_env():
    env = os.environ.copy()
    env['PATH'] = r'C:\msys64\mingw64\bin;' + env.get('PATH', '')
    return env

def parse_fixed(line: str, fields: List[tuple]) -> Dict[str, str]:
    """Parse a fixed-width line according to field (name, start_idx, length)"""
    res = {}
    for name, start, length in fields:
        res[name] = line[start:start+length].strip()
    return res

# ----------------- DATASET PARSERS -----------------
def read_customers():
    path = os.path.join(DATA_DIR, "CUSTMAST.DAT")
    if not os.path.exists(path):
        return []
    res = []
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if len(line.strip()) == 0:
                continue
            res.append({
                "cust_id": line[0:10].strip(),
                "name": line[10:40].strip(),
                "email": line[40:70].strip(),
                "phone": line[70:85].strip(),
                "status": line[85:86].strip(),
                "created_date": line[86:96].strip(),
            })
    return res

def read_subscriptions():
    path = os.path.join(DATA_DIR, "SUBMAST.DAT")
    if not os.path.exists(path):
        return []
    res = []
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if len(line.strip()) == 0:
                continue
            res.append({
                "sub_id": line[0:10].strip(),
                "cust_id": line[10:20].strip(),
                "plan_id": line[20:28].strip(),
                "start_date": line[28:38].strip(),
                "end_date": line[38:48].strip(),
                "duration_months": int(line[48:51].strip() or 0),
                "status": line[51:52].strip(),
                "next_bill_date": line[52:62].strip(),
            })
    return res

def read_plans():
    path = os.path.join(DATA_DIR, "PLANMAST.DAT")
    if not os.path.exists(path):
        return []
    res = []
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if len(line.strip()) == 0:
                continue
            amt_raw = line[33:42].strip()
            amt = float(amt_raw) / 100.0 if amt_raw.isdigit() else 0.0
            res.append({
                "plan_id": line[0:8].strip(),
                "name": line[8:33].strip(),
                "base_amount": amt,
                "cycle": line[42:43].strip(),
                "status": line[43:44].strip(),
            })
    return res

def read_payments():
    path = os.path.join(DATA_DIR, "PAYMENT.DAT")
    if not os.path.exists(path):
        return []
    res = []
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if len(line.strip()) == 0:
                continue
            amt_raw = line[22:31].strip()
            amt = float(amt_raw) / 100.0 if amt_raw.isdigit() else 0.0
            res.append({
                "txn_id": line[0:12].strip(),
                "sub_id": line[12:22].strip(),
                "amount": amt,
                "date": line[31:41].strip(),
                "mode": line[41:56].strip(),
                "status": line[56:66].strip(),
            })
    return res

def read_bills():
    path = os.path.join(DATA_DIR, "BILLS.DAT")
    if not os.path.exists(path):
        return []
    res = []
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if len(line.strip()) == 0:
                continue
            # BILL-ID(12), SUB-ID(10), CUST-ID(10), PLAN-ID(8), BASE(9), DISC-PCT(4), DISC-AMT(9), TAX-AMT(9), FINAL-AMT(9), DATE(10)
            base = float(line[40:49].strip() or 0) / 100.0
            dpct = float(line[49:53].strip() or 0) / 100.0
            damt = float(line[53:62].strip() or 0) / 100.0
            tax = float(line[62:71].strip() or 0) / 100.0
            fin = float(line[71:80].strip() or 0) / 100.0
            res.append({
                "bill_id": line[0:12].strip(),
                "sub_id": line[12:22].strip(),
                "cust_id": line[22:32].strip(),
                "plan_id": line[32:40].strip(),
                "base_amt": base,
                "disc_pct": dpct,
                "disc_amt": damt,
                "tax_amt": tax,
                "final_amt": fin,
                "date": line[80:90].strip()
            })
    return res

def read_payouts():
    path = os.path.join(DATA_DIR, "PAYOUT.DAT")
    if not os.path.exists(path):
        return []
    res = []
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if len(line.strip()) == 0:
                continue
            amt = float(line[34:43].strip() or 0) / 100.0
            res.append({
                "txn_id": line[0:12].strip(),
                "bill_id": line[12:24].strip(),
                "sub_id": line[24:34].strip(),
                "amount": amt,
                "date": line[43:53].strip(),
                "mode": line[53:68].strip(),
                "status": line[68:78].strip()
            })
    return res

def read_exceptions():
    path = os.path.join(DATA_DIR, "EXCEPTION.DAT")
    if not os.path.exists(path):
        return []
    res = []
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if len(line.strip()) == 0:
                continue
            res.append({
                "source_step": line[0:8].strip(),
                "record_key": line[8:20].strip(),
                "err_code": line[20:26].strip(),
                "err_desc": line[26:71].strip(),
                "timestamp": line[71:90].strip()
            })
    return res

def read_revenues():
    path = os.path.join(DATA_DIR, "REVENUE.DAT")
    if not os.path.exists(path):
        return []
    res = []
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if len(line.strip()) == 0:
                continue
            billed = float(line[38:49].strip() or 0) / 100.0
            recv = float(line[49:60].strip() or 0) / 100.0
            outstand = float(line[60:71].strip() or 0) / 100.0
            res.append({
                "plan_id": line[0:8].strip(),
                "plan_name": line[8:33].strip(),
                "sub_count": int(line[33:38].strip() or 0),
                "billed_amt": billed,
                "received_amt": recv,
                "outstanding_amt": outstand
            })
    return res

# ----------------- API ENDPOINTS -----------------
@app.get("/api/status")
def get_status():
    return {
        "system": {
            "name": "IBM z16 Enterprise Mainframe Batch Environment",
            "os": "z/OS V2R5 / MVS JES2",
            "compiler": "GnuCOBOL 3.2.0 (ANSI/Enterprise COBOL-85/2002/2014)",
            "host": "SYS-ZOS1",
            "batch_job": "SUBBILL01",
            "initiator": "INIT 01 (CLASS A)"
        },
        "datasets": {
            "customers": len(read_customers()),
            "subscriptions": len(read_subscriptions()),
            "plans": len(read_plans()),
            "payments": len(read_payments()),
            "bills": len(read_bills()),
            "payouts": len(read_payouts()),
            "exceptions": len(read_exceptions()),
            "revenue": len(read_revenues())
        },
        "active_job": {
            "job_id": "JOB04821",
            "max_cc": "0004",
            "status": "COMPLETED" if os.path.exists(os.path.join(DATA_DIR, "BILLRPT.TXT")) else "READY"
        }
    }

@app.get("/api/datasets")
def get_all_datasets():
    return {
        "customers": read_customers(),
        "subscriptions": read_subscriptions(),
        "plans": read_plans(),
        "payments": read_payments(),
        "bills": read_bills(),
        "payouts": read_payouts(),
        "exceptions": read_exceptions(),
        "revenue": read_revenues()
    }

@app.post("/api/batch/run")
def trigger_batch_run(user: Dict[str, Any] = Depends(require_roles(["SYSADMIN"], resource_name="BATCH.SUBBILL01.EXECUTE", action="EXECUTE"))):
    script_path = os.path.join(BASE_DIR, "scripts", "run_batch.py")
    start_time = time.time()
    res = subprocess.run([sys.executable, script_path], capture_output=True, text=True, cwd=BASE_DIR)
    duration = time.time() - start_time

    log_smf80_event(
        event_type="BATCH_EXEC",
        userid=user.get("sub", "SYSADMIN"),
        group=user.get("group", "SYS1"),
        resource="BATCH.SUBBILL01",
        status="SUCCESS" if res.returncode == 0 else "WARNING",
        rc=res.returncode,
        details=f"SUBBILL01 completed with RC={res.returncode:04d} in {duration:.2f}s"
    )

    return {
        "success": res.returncode == 0,
        "return_code": res.returncode,
        "duration_sec": round(duration, 3),
        "spool_output": res.stdout,
        "operator": user.get("sub"),
        "datasets": {
            "bills_generated": len(read_bills()),
            "payouts_verified": len(read_payouts()),
            "exceptions_diverted": len(read_exceptions()),
            "revenue_summary": read_revenues()
        }
    }

@app.post("/api/batch/step/{step_id}")
def run_single_step(step_id: str, user: Dict[str, Any] = Depends(require_roles(["SYSADMIN"], resource_name="BATCH.STEP.EXECUTE", action="EXECUTE"))):
    step_map = {
        "STEP01": ("IDCAMS", None),
        "STEP02": ("SUBVAL", os.path.join(BIN_DIR, "SUBVAL.exe")),
        "STEP03": ("BILLPROC", os.path.join(BIN_DIR, "BILLPROC.exe")),
        "STEP04": ("PAYPROC", os.path.join(BIN_DIR, "PAYPROC.exe")),
        "STEP05": ("REVPROC", os.path.join(BIN_DIR, "REVPROC.exe")),
        "STEP06": ("REPORT", os.path.join(BIN_DIR, "REPORT.exe"))
    }

    if step_id not in step_map:
        raise HTTPException(status_code=400, detail=f"Invalid step ID: {step_id}")

    name, exe = step_map[step_id]
    if step_id == "STEP01":
        # IDCAMS: Clean outputs
        for f in ['VALIDSUB.DAT', 'BILLS.DAT', 'PAYOUT.DAT', 'REVENUE.DAT', 'EXCEPTION.DAT',
                  'BILLRPT.TXT', 'REVRPT.TXT', 'EXCPRPT.TXT']:
            p = os.path.join(DATA_DIR, f)
            if os.path.exists(p):
                os.remove(p)
        log_smf80_event("STEP_EXEC", user["sub"], user["group"], "IDCAMS.STEP01", "SUCCESS", 0, "Purged VSAM clusters")
        return {
            "step": step_id,
            "program": name,
            "rc": 0,
            "stdout": "IDCAMS: WORKSPACE AND VSAM CLUSTERS PURGED AND REALLOCATED SUCCESSFULLY."
        }

    if not os.path.exists(exe):
        raise HTTPException(status_code=500, detail=f"Program executable {exe} not found. Please compile first.")

    res = subprocess.run([exe], capture_output=True, text=True, cwd=BASE_DIR, env=get_env())
    log_smf80_event("STEP_EXEC", user["sub"], user["group"], f"{name}.{step_id}", "SUCCESS", res.returncode, f"Completed RC={res.returncode:04d}")
    return {
        "step": step_id,
        "program": name,
        "rc": res.returncode,
        "stdout": res.stdout,
        "stderr": res.stderr
    }

@app.get("/api/reports")
def get_reports():
    reports = {}
    for rpt in ["BILLRPT.TXT", "REVRPT.TXT", "EXCPRPT.TXT"]:
        p = os.path.join(DATA_DIR, rpt)
        if os.path.exists(p):
            with open(p, "r", encoding="utf-8", errors="ignore") as f:
                reports[rpt] = f.read()
        else:
            reports[rpt] = "Report not yet generated. Please submit batch job SUBBILL01."
    return reports

# ----------------- PYDANTIC DATA MODELS -----------------
class LoginRequest(BaseModel):
    userid: str
    password: str

class UnlockRequest(BaseModel):
    userid: str

class NewCustomer(BaseModel):
    cust_id: str
    name: str
    email: str
    phone: str
    status: str = "A"
    reg_date: str = "2024-01-15"

class NewSubscription(BaseModel):
    sub_id: str
    cust_id: str
    plan_id: str
    duration_months: int
    status: str = "A"
    next_bill_date: str = "2026-10-01"

class NewPlan(BaseModel):
    plan_id: str
    name: str
    base_amount: float
    cycle: str = "M"
    status: str = "A"

class NewPayment(BaseModel):
    txn_id: str
    sub_id: str
    amount: float
    mode: str = "UPI"
    status: str = "SUCCESS"

class AnomalyRequest(BaseModel):
    scenario: str

class FixExceptionRequest(BaseModel):
    record_key: str
    err_code: str

# ----------------- RACF AUTHENTICATION & SECURITY ENDPOINTS -----------------
@app.post("/api/auth/login")
def login(creds: LoginRequest, request: Request):
    userid = creds.userid.strip().upper()
    client_ip = request.client.host if request.client else "127.0.0.1"
    
    # 1. Check account lockout status
    check_account_lockout(userid)
    
    # 2. Verify user existence
    user = USERS_DB.get(userid)
    if not user:
        record_failed_attempt(userid, client_ip)
        raise HTTPException(
            status_code=401,
            detail=f"ICH408I USER({userid}) NOT FOUND IN RACF DATABASE. INVALID LOGON PARAMETERS."
        )
        
    # 3. Verify password
    if not verify_password(creds.password, user["password_hash"]):
        record_failed_attempt(userid, client_ip)
        remaining = 5 - user.get("failed_attempts", 0)
        raise HTTPException(
            status_code=401,
            detail=f"ICH408I INVALID RACF PASSWORD FOR USER({userid}). Attempts remaining before revocation: {remaining}"
        )
        
    # 4. Successful logon
    record_successful_login(userid, client_ip)
    token = create_access_token(user)
    
    return {
        "success": True,
        "token": token,
        "user": {
            "userid": user["userid"],
            "name": user["name"],
            "group": user["group"],
            "role": user["role"],
            "permissions": user["permissions"]
        },
        "session": {
            "system": "SYS-ZOS1",
            "logon_time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "token_type": "Bearer"
        }
    }

@app.post("/api/auth/logout")
def logout(user: Dict[str, Any] = Depends(get_current_user), request: Request = None):
    auth_hdr = request.headers.get("authorization", "") if request else ""
    if auth_hdr.lower().startswith("bearer "):
        token = auth_hdr.split(" ", 1)[1].strip()
        REVOKED_TOKENS.add(token)
    
    client_ip = request.client.host if request and request.client else "127.0.0.1"
    log_smf80_event(
        event_type="LOGOFF",
        userid=user.get("sub", "UNKNOWN"),
        group=user.get("group", "NONE"),
        resource="RACF.SESSION",
        status="SUCCESS",
        rc=0,
        details="User voluntarily terminated terminal session.",
        ip=client_ip
    )
    return {"message": f"RACF Session terminated for {user.get('sub')}."}

@app.get("/api/auth/me")
def get_current_user_profile(user: Dict[str, Any] = Depends(get_current_user)):
    return user

@app.get("/api/auth/users")
def list_demo_users():
    """List available demo RACF users with roles and descriptions for educational review."""
    return [
        {
            "userid": "SYSADMIN",
            "name": "Prof. Madhura Sanap / Lead SysProg",
            "role": "SYSADMIN",
            "group": "SYS1",
            "desc": "Full Master Authority: JCL batch execution, IDCAMS step purges, master dataset reset, defect injection, security audit management.",
            "demo_password": "Pass123!ADMIN"
        },
        {
            "userid": "BILLMGR",
            "name": "Aditi Kadam / Billing Supervisor",
            "role": "BILLMGR",
            "group": "FINGRP",
            "desc": "Financial Authority: Can review datasets, export management registers, inspect revenue reconciliations. Restricted from running batch steps or resetting master files.",
            "demo_password": "Pass123!BILL"
        },
        {
            "userid": "DATAOPR",
            "name": "Sharayu Itkikar / Data Operator",
            "role": "DATAOPR",
            "group": "OPSGRP",
            "desc": "Operations Authority: Add/edit customer & subscription master data, repair exceptions. Cannot run IDCAMS step purge or reset master files.",
            "demo_password": "Pass123!DATA"
        },
        {
            "userid": "AUDITOR",
            "name": "Smruti Gadave / Internal Auditor",
            "role": "AUDITOR",
            "group": "AUDITGRP",
            "desc": "Compliance Authority: Strictly read-only access to datasets, reports, spool logs, and SMF Type 80 audit logs. All mutation attempts trigger RACF 403 violations.",
            "demo_password": "Pass123!AUDIT"
        }
    ]

@app.get("/api/security/audit-log")
def get_security_audit_log(limit: int = 50, user: Dict[str, Any] = Depends(get_current_user)):
    """Retrieve SMF Type 80 Security Records (requires authenticated RACF session)."""
    return {
        "total_records": len(SECURITY_AUDIT_LOG),
        "records": SECURITY_AUDIT_LOG[:limit]
    }

@app.get("/api/security/stats")
def get_security_stats():
    """Summary of security metrics for the dashboard."""
    violations = [e for e in SECURITY_AUDIT_LOG if e.get("racf_rc") == 8]
    logins = [e for e in SECURITY_AUDIT_LOG if e.get("event_type") == "LOGON_SUCCESS"]
    failed = [e for e in SECURITY_AUDIT_LOG if e.get("event_type") == "LOGON_FAILED"]
    locked = [u for u, d in USERS_DB.items() if d.get("lockout_until", 0) > time.time()]
    return {
        "total_events": len(SECURITY_AUDIT_LOG),
        "successful_logins": len(logins),
        "failed_attempts": len(failed),
        "racf_violations": len(violations),
        "locked_accounts": locked,
        "users_count": len(USERS_DB)
    }

@app.post("/api/security/unlock")
def unlock_user_account(req: UnlockRequest, user: Dict[str, Any] = Depends(require_roles(["SYSADMIN"], resource_name="SECURITY.USER.UNLOCK", action="ALTER"))):
    target = req.userid.strip().upper()
    if target in USERS_DB:
        USERS_DB[target]["failed_attempts"] = 0
        USERS_DB[target]["lockout_until"] = 0
        log_smf80_event("ACCOUNT_UNLOCKED", user["sub"], user["group"], "RACF.USERS", "SUCCESS", 0, f"Operator unlocked account {target}")
        return {"message": f"Account {target} successfully reinstated."}
    raise HTTPException(status_code=404, detail=f"User {target} not found in RACF directory.")

# ----------------- DATASET MUTATION ENDPOINTS (RBAC PROTECTED) -----------------
@app.post("/api/datasets/customer")
def add_customer(cust: NewCustomer, user: Dict[str, Any] = Depends(require_roles(["SYSADMIN", "DATAOPR"], resource_name="DATASET.CUSTMAST.UPDATE", action="INSERT"))):
    path = os.path.join(DATA_DIR, "CUSTMAST.DAT")
    # CUST-ID(10), NAME(30), EMAIL(30), PHONE(15), STATUS(1), REG(10), FILLER(4) = 100
    line = f"{cust.cust_id:<10}{cust.name:<30}{cust.email:<30}{cust.phone:<15}{cust.status:<1}{cust.reg_date:<10}{' ':4}\n"
    with open(path, "a", encoding="utf-8") as f:
        f.write(line)
    log_smf80_event("DATA_MUTATION", user["sub"], user["group"], "DATASET.CUSTMAST", "SUCCESS", 0, f"Inserted Customer {cust.cust_id}")
    return {"message": f"Customer {cust.cust_id} added successfully by {user['sub']}."}

@app.put("/api/datasets/customer/{cust_id}")
def update_customer(cust_id: str, cust: NewCustomer, user: Dict[str, Any] = Depends(require_roles(["SYSADMIN", "DATAOPR"], resource_name="DATASET.CUSTMAST.UPDATE", action="UPDATE"))):
    path = os.path.join(DATA_DIR, "CUSTMAST.DAT")
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="Dataset not found.")
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    updated = False
    new_lines = []
    for line in lines:
        if line[:10].strip() == cust_id.strip():
            new_lines.append(f"{cust.cust_id:<10}{cust.name:<30}{cust.email:<30}{cust.phone:<15}{cust.status:<1}{cust.reg_date:<10}{' ':4}\n")
            updated = True
        else:
            new_lines.append(line)
    if not updated:
        raise HTTPException(status_code=404, detail="Customer ID not found.")
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
    log_smf80_event("DATA_MUTATION", user["sub"], user["group"], "DATASET.CUSTMAST", "SUCCESS", 0, f"Updated Customer {cust_id}")
    return {"message": f"Customer {cust_id} updated successfully by {user['sub']}."}

@app.post("/api/datasets/subscription")
def add_subscription(sub: NewSubscription, user: Dict[str, Any] = Depends(require_roles(["SYSADMIN", "DATAOPR"], resource_name="DATASET.SUBMAST.UPDATE", action="INSERT"))):
    path = os.path.join(DATA_DIR, "SUBMAST.DAT")
    # SUB-ID(10), SUB-CUST-ID(10), SUB-PLAN-ID(8), START(10), END(10), DUR(3), STATUS(1), BILL(10), FILLER(18) = 80
    line = f"{sub.sub_id:<10}{sub.cust_id:<10}{sub.plan_id:<8}2024-01-012025-01-01{sub.duration_months:03d}{sub.status:<1}{sub.next_bill_date:<10}{' ':18}\n"
    with open(path, "a", encoding="utf-8") as f:
        f.write(line)
    log_smf80_event("DATA_MUTATION", user["sub"], user["group"], "DATASET.SUBMAST", "SUCCESS", 0, f"Inserted Subscription {sub.sub_id}")
    return {"message": f"Subscription {sub.sub_id} added successfully by {user['sub']}."}

@app.put("/api/datasets/subscription/{sub_id}")
def update_subscription(sub_id: str, sub: NewSubscription, user: Dict[str, Any] = Depends(require_roles(["SYSADMIN", "DATAOPR"], resource_name="DATASET.SUBMAST.UPDATE", action="UPDATE"))):
    path = os.path.join(DATA_DIR, "SUBMAST.DAT")
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="Dataset not found.")
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    updated = False
    new_lines = []
    for line in lines:
        if line[:10].strip() == sub_id.strip():
            new_lines.append(f"{sub.sub_id:<10}{sub.cust_id:<10}{sub.plan_id:<8}2024-01-012025-01-01{sub.duration_months:03d}{sub.status:<1}{sub.next_bill_date:<10}{' ':18}\n")
            updated = True
        else:
            new_lines.append(line)
    if not updated:
        raise HTTPException(status_code=404, detail="Subscription ID not found.")
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
    log_smf80_event("DATA_MUTATION", user["sub"], user["group"], "DATASET.SUBMAST", "SUCCESS", 0, f"Updated Subscription {sub_id}")
    return {"message": f"Subscription {sub_id} updated successfully by {user['sub']}."}

@app.post("/api/datasets/plan")
def add_plan(plan: NewPlan, user: Dict[str, Any] = Depends(require_roles(["SYSADMIN"], resource_name="DATASET.PLANMAST.UPDATE", action="INSERT"))):
    path = os.path.join(DATA_DIR, "PLANMAST.DAT")
    amt_int = int(round(plan.base_amount * 100))
    line = f"{plan.plan_id:<8}{plan.name:<25}{amt_int:09d}{plan.cycle:<1}{plan.status:<1}{' ':16}\n"
    with open(path, "a", encoding="utf-8") as f:
        f.write(line)
    log_smf80_event("DATA_MUTATION", user["sub"], user["group"], "DATASET.PLANMAST", "SUCCESS", 0, f"Inserted Plan {plan.plan_id}")
    return {"message": f"Plan {plan.plan_id} added successfully."}

@app.put("/api/datasets/plan/{plan_id}")
def update_plan(plan_id: str, plan: NewPlan, user: Dict[str, Any] = Depends(require_roles(["SYSADMIN"], resource_name="DATASET.PLANMAST.UPDATE", action="UPDATE"))):
    path = os.path.join(DATA_DIR, "PLANMAST.DAT")
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="Dataset not found.")
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    updated = False
    new_lines = []
    amt_int = int(round(plan.base_amount * 100))
    for line in lines:
        if line[:8].strip() == plan_id.strip():
            new_lines.append(f"{plan.plan_id:<8}{plan.name:<25}{amt_int:09d}{plan.cycle:<1}{plan.status:<1}{' ':16}\n")
            updated = True
        else:
            new_lines.append(line)
    if not updated:
        raise HTTPException(status_code=404, detail="Plan ID not found.")
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
    log_smf80_event("DATA_MUTATION", user["sub"], user["group"], "DATASET.PLANMAST", "SUCCESS", 0, f"Updated Plan {plan_id}")
    return {"message": f"Plan {plan_id} updated successfully."}

@app.post("/api/datasets/payment")
def add_payment(pay: NewPayment, user: Dict[str, Any] = Depends(require_roles(["SYSADMIN", "DATAOPR"], resource_name="DATASET.PAYMENT.UPDATE", action="INSERT"))):
    path = os.path.join(DATA_DIR, "PAYMENT.DAT")
    amt_int = int(round(pay.amount * 100))
    line = f"{pay.txn_id:<12}{pay.sub_id:<10}{amt_int:09d}2026-10-02{pay.mode:<15}{pay.status:<10}{' ':14}\n"
    with open(path, "a", encoding="utf-8") as f:
        f.write(line)
    log_smf80_event("DATA_MUTATION", user["sub"], user["group"], "DATASET.PAYMENT", "SUCCESS", 0, f"Inserted Payment {pay.txn_id}")
    return {"message": f"Payment {pay.txn_id} added successfully by {user['sub']}."}

@app.put("/api/datasets/payment/{txn_id}")
def update_payment(txn_id: str, pay: NewPayment, user: Dict[str, Any] = Depends(require_roles(["SYSADMIN", "DATAOPR"], resource_name="DATASET.PAYMENT.UPDATE", action="UPDATE"))):
    path = os.path.join(DATA_DIR, "PAYMENT.DAT")
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="Dataset not found.")
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    updated = False
    new_lines = []
    amt_int = int(round(pay.amount * 100))
    for line in lines:
        if line[:12].strip() == txn_id.strip():
            new_lines.append(f"{pay.txn_id:<12}{pay.sub_id:<10}{amt_int:09d}2026-10-02{pay.mode:<15}{pay.status:<10}{' ':14}\n")
            updated = True
        else:
            new_lines.append(line)
    if not updated:
        raise HTTPException(status_code=404, detail="Payment Txn ID not found.")
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
    log_smf80_event("DATA_MUTATION", user["sub"], user["group"], "DATASET.PAYMENT", "SUCCESS", 0, f"Updated Payment {txn_id}")
    return {"message": f"Payment {txn_id} updated successfully by {user['sub']}."}

@app.post("/api/datasets/fix-exception")
def fix_exception(req: FixExceptionRequest, user: Dict[str, Any] = Depends(require_roles(["SYSADMIN", "DATAOPR"], resource_name="DATASET.EXCEPTION.RESOLVE", action="UPDATE"))):
    key = req.record_key.strip()
    code = req.err_code.strip()

    # If customer inactive/suspended, activate customer
    if "CUST" in code or key.startswith("CUST"):
        path = os.path.join(DATA_DIR, "CUSTMAST.DAT")
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8") as f:
                lines = f.readlines()
            new_lines = []
            for l in lines:
                if l[:10].strip() == key:
                    new_lines.append(l[:85] + 'A' + l[86:])
                else:
                    new_lines.append(l)
            with open(path, "w", encoding="utf-8") as f:
                f.writelines(new_lines)

    # If sub expired or inactive, activate subscription
    if "SUB" in code or key.startswith("SUB"):
        path = os.path.join(DATA_DIR, "SUBMAST.DAT")
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8") as f:
                lines = f.readlines()
            new_lines = []
            for l in lines:
                if l[:10].strip() == key:
                    new_lines.append(l[:51] + 'A' + '2026-10-01' + l[62:])
                else:
                    new_lines.append(l)
            with open(path, "w", encoding="utf-8") as f:
                f.writelines(new_lines)

    # If payment mismatch or failed, fix payment
    if "PAY" in code or "AMT" in code or key.startswith("TXN"):
        path = os.path.join(DATA_DIR, "PAYMENT.DAT")
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8") as f:
                lines = f.readlines()
            new_lines = []
            for l in lines:
                if l[:12].strip() == key:
                    new_lines.append(l[:56] + 'SUCCESS   ' + l[66:])
                else:
                    new_lines.append(l)
            with open(path, "w", encoding="utf-8") as f:
                f.writelines(new_lines)

    log_smf80_event("EXCEPTION_RESOLVED", user["sub"], user["group"], "DATASET.EXCEPTION", "SUCCESS", 0, f"Resolved defect {key} ({code})")
    return {"message": f"Record {key} corrected by {user['sub']}. Ready to rerun billing cycle."}

@app.get("/api/datasets/export/{dataset_name}")
def export_dataset_csv(dataset_name: str):
    dataset_name = dataset_name.lower().strip()
    allowed_targets = ["customers", "subscriptions", "plans", "payments", "bills", "payouts", "revenue", "exceptions"]
    if dataset_name not in allowed_targets:
        raise HTTPException(status_code=400, detail=f"ICH408I SECURITY VIOLATION: Invalid dataset export target: {dataset_name}")

    output = io.StringIO()
    writer = csv.writer(output)

    if dataset_name == "customers":
        writer.writerow(["Customer_ID", "Name", "Email", "Phone", "Status", "Reg_Date"])
        for c in read_customers():
            writer.writerow([c["cust_id"], c["name"], c["email"], c["phone"], c["status"], c["reg_date"]])
    elif dataset_name == "subscriptions":
        writer.writerow(["Subscription_ID", "Customer_ID", "Plan_ID", "Duration_Months", "Status", "Next_Bill_Date"])
        for s in read_subscriptions():
            writer.writerow([s["sub_id"], s["cust_id"], s["plan_id"], s["duration_months"], s["status"], s["next_bill_date"]])
    elif dataset_name == "plans":
        writer.writerow(["Plan_ID", "Plan_Name", "Monthly_Base_Amount", "Cycle", "Status"])
        for p in read_plans():
            writer.writerow([p["plan_id"], p["name"], p["base_amount"], p["cycle"], p["status"]])
    elif dataset_name == "payments":
        writer.writerow(["Transaction_ID", "Subscription_ID", "Amount", "Date", "Payment_Mode", "Status"])
        for p in read_payments():
            writer.writerow([p["txn_id"], p["sub_id"], p["amount"], p["date"], p["mode"], p["status"]])
    elif dataset_name == "bills":
        writer.writerow(["Bill_ID", "Subscription_ID", "Customer_ID", "Plan_ID", "Base_Amount", "Discount_Pct", "Discount_Amt", "Tax_Amt", "Final_Bill", "Date"])
        for b in read_bills():
            writer.writerow([b["bill_id"], b["sub_id"], b["cust_id"], b["plan_id"], b["base_amt"], b["disc_pct"], b["disc_amt"], b["tax_amt"], b["final_amt"], b["date"]])
    elif dataset_name == "payouts":
        writer.writerow(["Transaction_ID", "Bill_ID", "Subscription_ID", "Amount", "Date", "Mode", "Match_Status"])
        for p in read_payouts():
            writer.writerow([p["txn_id"], p["bill_id"], p["sub_id"], p["amount"], p["date"], p["mode"], p["status"]])
    elif dataset_name == "revenue":
        writer.writerow(["Plan_ID", "Plan_Name", "Sub_Count", "Billed_Amount", "Received_Amount", "Outstanding_Amount"])
        for r in read_revenues():
            writer.writerow([r["plan_id"], r["plan_name"], r["sub_count"], r["billed_amt"], r["received_amt"], r["outstanding_amt"]])
    elif dataset_name == "exceptions":
        writer.writerow(["Source_Step", "Record_Key", "Error_Code", "Error_Description", "Timestamp"])
        for e in read_exceptions():
            writer.writerow([e["source_step"], e["record_key"], e["err_code"], e["err_desc"], e["timestamp"]])

    csv_data = output.getvalue()
    return Response(
        content=csv_data,
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={dataset_name}.csv"}
    )

@app.post("/api/datasets/inject")
def inject_anomaly(req: AnomalyRequest, user: Dict[str, Any] = Depends(require_roles(["SYSADMIN"], resource_name="DATASET.ANOMALY.INJECT", action="ALTER"))):
    scenario = req.scenario.upper()
    if scenario == "NORMAL":
        script = os.path.join(BASE_DIR, "scripts", "generate_data.py")
        subprocess.run([sys.executable, script], cwd=BASE_DIR)
        log_smf80_event("ANOMALY_INJECT", user["sub"], user["group"], "DATASET.ALL", "SUCCESS", 0, "Restored factory standard datasets")
        return {"message": "Factory standard master datasets restored."}

    elif scenario == "MIXED_ERRORS":
        sub_path = os.path.join(DATA_DIR, "SUBMAST.DAT")
        line = f"{'SUB9990001':<10}{'CUST000101':<10}{'PLAN-001':<8}2023-01-012023-12-01012A2023-05-01{' ':18}\n"
        with open(sub_path, "a", encoding="utf-8") as f:
            f.write(line)

        pay_path = os.path.join(DATA_DIR, "PAYMENT.DAT")
        line_mis = f"{'TXN9990001':<12}{'SUB1000001':<10}{'000001000':<9}2026-10-02UPI            SUCCESS                 \n"
        line_fail = f"{'TXN9990002':<12}{'SUB1000002':<10}{'000111988':<9}2026-10-02CREDIT_CARD    FAILED                  \n"
        line_dup = f"{'TXN202610011':<12}{'SUB1000001':<10}{'000106094':<9}2026-10-02UPI            SUCCESS                 \n"
        with open(pay_path, "a", encoding="utf-8") as f:
            f.write(line_mis)
            f.write(line_fail)
            f.write(line_dup)

        log_smf80_event("ANOMALY_INJECT", user["sub"], user["group"], "DATASET.MIXED", "SUCCESS", 0, "Injected mixed anomalies")
        return {"message": "Injected Mixed Real-World Errors: 1 Expired Sub, 1 Payment Mismatch, 1 Gateway Failure, 1 Duplicate Txn."}

    elif scenario == "EXPIRED_SUB":
        sub_path = os.path.join(DATA_DIR, "SUBMAST.DAT")
        line = f"{'SUB9990001':<10}{'CUST000101':<10}{'PLAN-001':<8}2023-01-012023-12-01012A2023-05-01{' ':18}\n"
        with open(sub_path, "a", encoding="utf-8") as f:
            f.write(line)
        log_smf80_event("ANOMALY_INJECT", user["sub"], user["group"], "DATASET.SUBMAST", "SUCCESS", 0, "Injected expired subscription")
        return {"message": "Injected Expired Subscription (SUB9990001 with Bill Date 2023-05-01)."}

    elif scenario == "INACTIVE_CUST":
        c_path = os.path.join(DATA_DIR, "CUSTMAST.DAT")
        c_line = f"{'CUST999099':<10}{'Defunct Offshore Corp         ':<30}{'insolvent@badcorp.com         ':<30}{'+1-800-999-0000':<15}{'I':<1}2020-01-01    \n"
        with open(c_path, "a", encoding="utf-8") as f:
            f.write(c_line)
        s_path = os.path.join(DATA_DIR, "SUBMAST.DAT")
        s_line = f"{'SUB9990002':<10}{'CUST999099':<10}{'PLAN-002':<8}2024-01-012025-01-01006A2026-10-01{' ':18}\n"
        with open(s_path, "a", encoding="utf-8") as f:
            f.write(s_line)
        log_smf80_event("ANOMALY_INJECT", user["sub"], user["group"], "DATASET.CUSTMAST", "SUCCESS", 0, "Injected inactive customer")
        return {"message": "Injected Inactive Customer CUST999099 & linked SUB9990002."}

    elif scenario == "AMOUNT_MISMATCH":
        pay_path = os.path.join(DATA_DIR, "PAYMENT.DAT")
        line = f"{'TXN9990001':<12}{'SUB1000001':<10}{'000001000':<9}2026-10-02UPI            SUCCESS                 \n"
        with open(pay_path, "a", encoding="utf-8") as f:
            f.write(line)
        log_smf80_event("ANOMALY_INJECT", user["sub"], user["group"], "DATASET.PAYMENT", "SUCCESS", 0, "Injected amount mismatch")
        return {"message": "Injected Amount Mismatch Payment TXN9990001 ($10.00 for $1,060.94 bill)."}

    elif scenario == "DUPLICATE_PAY":
        pay_path = os.path.join(DATA_DIR, "PAYMENT.DAT")
        line = f"{'TXN202610011':<12}{'SUB1000001':<10}{'000106094':<9}2026-10-02UPI            SUCCESS                 \n"
        with open(pay_path, "a", encoding="utf-8") as f:
            f.write(line)
        log_smf80_event("ANOMALY_INJECT", user["sub"], user["group"], "DATASET.PAYMENT", "SUCCESS", 0, "Injected duplicate payment")
        return {"message": "Injected Duplicate Payment TXN202610011."}

    elif scenario == "FAILED_GATEWAY":
        pay_path = os.path.join(DATA_DIR, "PAYMENT.DAT")
        line = f"{'TXN9990009':<12}{'SUB1000003':<10}{'000501400':<9}2026-10-02CREDIT_CARD    FAILED                  \n"
        with open(pay_path, "a", encoding="utf-8") as f:
            f.write(line)
        log_smf80_event("ANOMALY_INJECT", user["sub"], user["group"], "DATASET.PAYMENT", "SUCCESS", 0, "Injected gateway failure")
        return {"message": "Injected Failed Gateway Transaction TXN9990009."}

    else:
        raise HTTPException(status_code=400, detail=f"Unknown scenario: {scenario}")

@app.delete("/api/datasets/{dataset_name}/{record_id}")
def delete_record(dataset_name: str, record_id: str, user: Dict[str, Any] = Depends(require_roles(["SYSADMIN"], resource_name="DATASET.RECORD.DELETE", action="DELETE"))):
    file_map = {
        "customers": ("CUSTMAST.DAT", 10),
        "subscriptions": ("SUBMAST.DAT", 10),
        "payments": ("PAYMENT.DAT", 12)
    }
    if dataset_name not in file_map:
        raise HTTPException(status_code=400, detail="Cannot delete from this dataset.")
    fname, key_len = file_map[dataset_name]
    path = os.path.join(DATA_DIR, fname)
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="Dataset not found.")
    
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    
    new_lines = [l for l in lines if l[:key_len].strip() != record_id.strip()]
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
    
    log_smf80_event("DATA_DELETE", user["sub"], user["group"], f"DATASET.{dataset_name.upper()}", "SUCCESS", 0, f"Deleted record {record_id}")
    return {"message": f"Record {record_id} removed from {fname} by {user['sub']}."}

@app.get("/api/source/{category}/{filename}")
def get_source_file(category: str, filename: str):
    if ".." in filename or "/" in filename or "\\" in filename or not re.match(r'^[A-Za-z0-9_\-\.]+$', filename):
        raise HTTPException(status_code=400, detail="ICH408I SECURITY VIOLATION: Path traversal or invalid characters detected in resource path.")
    allowed_dirs = {
        "cobol": os.path.join(BASE_DIR, "cobol"),
        "jcl": os.path.join(BASE_DIR, "jcl"),
        "copybooks": os.path.join(BASE_DIR, "copybooks")
    }
    if category not in allowed_dirs:
        raise HTTPException(status_code=400, detail="Invalid source category.")
    dir_path = allowed_dirs[category]
    file_path = os.path.abspath(os.path.join(dir_path, filename))
    if not file_path.startswith(os.path.abspath(dir_path)):
        raise HTTPException(status_code=403, detail="Security violation: Path outside permitted directory.")
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="File not found.")
    with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
        return {"category": category, "filename": filename, "content": f.read()}

@app.get("/api/source/list")
def list_source_files():
    return {
        "jcl": sorted(os.listdir(os.path.join(BASE_DIR, "jcl"))),
        "cobol": sorted(os.listdir(os.path.join(BASE_DIR, "cobol"))),
        "copybooks": sorted(os.listdir(os.path.join(BASE_DIR, "copybooks")))
    }

@app.post("/api/datasets/reset")
def reset_datasets(user: Dict[str, Any] = Depends(require_roles(["SYSADMIN"], resource_name="DATASET.PURGE.ALL", action="PURGE"))):
    script = os.path.join(BASE_DIR, "scripts", "generate_data.py")
    subprocess.run([sys.executable, script], cwd=BASE_DIR)
    log_smf80_event("DATASET_PURGE", user["sub"], user["group"], "DATASET.ALL", "SUCCESS", 0, "Master datasets reset to initial state")
    return {"message": "Master datasets restored to initial state."}

@app.get("/api/patent")
def get_patent_info():
    return {
        "title": "A Mainframe-Based Automated Batch System and Method for Subscription Billing, Payment Validation and Revenue Reporting",
        "applicants": [
            {"name": "Vishwakarma Institute of Technology", "nationality": "Indian", "address": "666, Upper Indiranagar, Bibwewadi, Pune, Maharashtra, India – 411 037"},
            {"name": "Vishwakarma University", "nationality": "Indian", "address": "Survey No 2, 3, 4, Kondhwa Main Rd, Laxmi Nagar, Betal Nagar, Kondhwa, Pune, Maharashtra, India - 411048"}
        ],
        "inventors": [
            {"name": "Prof. Madhura Sanap", "dept": "Department of Computer Science & Engineering (Data Science), Vishwakarma Institute of Technology, Pune", "email": "madhura.sanap@vit.edu", "phone": "9766001130", "sig": "/drawings/signature_madhura_sanap.png"},
            {"name": "Aditi Prakash Kadam", "dept": "Department of Computer Science & Engineering (Data Science), Vishwakarma Institute of Technology, Pune", "email": "aditi.kadam24@vit.edu", "phone": "9209253813", "sig": "/drawings/signature_aditi_kadam.png"},
            {"name": "Sharayu Abhijit Itkikar", "dept": "Department of Computer Science & Engineering (Data Science), Vishwakarma Institute of Technology, Pune", "email": "sharayu.itkikar24@vit.edu", "phone": "8446012951", "sig": "/drawings/signature_sharayu_itkikar.png"},
            {"name": "Smruti Babruwan Gadave", "dept": "Department of Computer Science & Engineering (Data Science), Vishwakarma Institute of Technology, Pune", "email": "smruti.1252040011@vit.edu", "phone": "9511746098", "sig": ""}
        ],
        "figures": [
            {"fig": "FIG. 1", "title": "Overall System Architecture (100)", "src": "/drawings/FIG1_System_Architecture.png", "desc": "Input datasets (110), JCL batch control (120), COBOL programs (130: SUBVAL, BILLPROC, PAYPROC, REVPROC, REPORT), Data layer (140), Exception dataset (150), Reports (160)."},
            {"fig": "FIG. 2", "title": "Batch Execution and Exception Flow (201-209)", "src": "/drawings/FIG2_Batch_Execution_Flow.png", "desc": "Step sequencing 201-207 with return-code gating and diversion of invalid/failed records to exception dataset 208."},
            {"fig": "FIG. 3", "title": "Dataset and File Operations", "src": "/drawings/FIG3_Dataset_File_Operations.png", "desc": "Mapping of VSAM KSDS master datasets and sequential transaction datasets across job steps of SUBBILL01."},
            {"fig": "FIG. 4", "title": "Validation, Billing and Payment Rules (301-324)", "src": "/drawings/FIG4_Validation_Billing_Payment_Rules.png", "desc": "Validation rules 301-304, billing discount duration tiers 311-314 (3-6m: 5%, 7-12m: 10%, >12m: 15%, tax 18%), and payment reconciliation 321-324."}
        ]
    }

# ----------------- STATIC FRONTEND & ASSET MOUNT -----------------
from fastapi.responses import FileResponse

@app.get("/")
def serve_index():
    index_file = os.path.join(FRONTEND_DIR, "index.html")
    if os.path.exists(index_file):
        return FileResponse(index_file)
    return {"message": "Mainframe API running. Frontend index.html not found."}

app.mount("/drawings", StaticFiles(directory=os.path.join(DOCS_DIR, "drawings")), name="drawings")
app.mount("/static", StaticFiles(directory=FRONTEND_DIR), name="frontend_static")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.server:app", host="0.0.0.0", port=8000, reload=True)
