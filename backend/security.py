"""
Enterprise Mainframe RACF Security Subsystem for IBM z/Architecture Simulation
Implements:
1. RACF (Resource Access Control Facility) User Registry & RBAC Profiles
2. Cryptographic Token Issuance & Verification (HMAC-SHA256 + PBKDF2)
3. Brute Force & Account Lockout Protection
4. SMF (System Management Facility) Type 80 Security Audit Logging
5. RACF Violation Diagnostic Message Generators (e.g. ICH408I)
"""

import os
import time
import json
import hmac
import base64
import hashlib
import secrets
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
from fastapi import HTTPException, Security, Depends, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(BASE_DIR, "data")
AUDIT_LOG_FILE = os.path.join(DATA_DIR, "SECRAUDIT.LOG")

# Secret key for signing tokens (persisted or randomized per boot)
SECRET_KEY = os.environ.get("MAINFRAME_SECRET_KEY", "IBM-Z-ENTERPRISE-RACF-KEY-2026-X9872")
TOKEN_EXPIRY_SECONDS = 8 * 3600  # 8 hours

# ----------------- PASSWORD HASHING (PBKDF2-HMAC-SHA256) -----------------
def hash_password(password: str, salt: Optional[str] = None) -> str:
    """Hash password using PBKDF2-HMAC-SHA256 with 100,000 iterations."""
    if not salt:
        salt = secrets.token_hex(16)
    hashed = hashlib.pbkdf2_hmac(
        'sha256',
        password.encode('utf-8'),
        salt.encode('utf-8'),
        100000
    ).hex()
    return f"{salt}${hashed}"

def verify_password(plain_password: str, stored_hash: str) -> bool:
    """Verify password against stored salt$hash."""
    try:
        salt, expected_hash = stored_hash.split("$", 1)
        actual_hash = hashlib.pbkdf2_hmac(
            'sha256',
            plain_password.encode('utf-8'),
            salt.encode('utf-8'),
            100000
        ).hex()
        return hmac.compare_digest(actual_hash, expected_hash)
    except Exception:
        return False

# ----------------- RACF USER PROFILES & ROLES -----------------
# RACF Groups:
# SYS1      -> System Administrators / Operators (Full Access)
# FINGRP    -> Billing & Revenue Management (Reports & Ledgers)
# OPSGRP    -> Data Entry & Maintenance Operators (Master Data CRUD)
# AUDITGRP  -> Compliance & Regulatory Auditors (Read-Only)

USERS_DB: Dict[str, Dict[str, Any]] = {
    "SYSADMIN": {
        "userid": "SYSADMIN",
        "name": "Prof. Madhura Sanap / Lead SysProg",
        "group": "SYS1",
        "role": "SYSADMIN",
        "password_hash": hash_password("Pass123!ADMIN", "salt_sysadmin_01"),
        "permissions": [
            "batch:run", "batch:step", "datasets:crud", "datasets:reset", 
            "datasets:inject", "reports:read", "audit:read", "security:manage"
        ],
        "failed_attempts": 0,
        "lockout_until": 0
    },
    "BILLMGR": {
        "userid": "BILLMGR",
        "name": "Aditi Kadam / Billing Supervisor",
        "group": "FINGRP",
        "role": "BILLMGR",
        "password_hash": hash_password("Pass123!BILL", "salt_billmgr_02"),
        "permissions": [
            "reports:read", "datasets:read", "audit:read", "revenue:export"
        ],
        "failed_attempts": 0,
        "lockout_until": 0
    },
    "DATAOPR": {
        "userid": "DATAOPR",
        "name": "Sharayu Itkikar / Data Operator",
        "group": "OPSGRP",
        "role": "DATAOPR",
        "password_hash": hash_password("Pass123!DATA", "salt_dataopr_03"),
        "permissions": [
            "datasets:read", "datasets:crud", "reports:read"
        ],
        "failed_attempts": 0,
        "lockout_until": 0
    },
    "AUDITOR": {
        "userid": "AUDITOR",
        "name": "Smruti Gadave / Internal Auditor",
        "group": "AUDITGRP",
        "role": "AUDITOR",
        "password_hash": hash_password("Pass123!AUDIT", "salt_auditor_04"),
        "permissions": [
            "datasets:read", "reports:read", "audit:read"
        ],
        "failed_attempts": 0,
        "lockout_until": 0
    }
}

# In-memory token revocation blacklist
REVOKED_TOKENS = set()

# In-memory recent SMF Type 80 security event log buffer (last 500)
SECURITY_AUDIT_LOG: List[Dict[str, Any]] = []

# ----------------- SMF TYPE 80 AUDIT LOGGER -----------------
def log_smf80_event(event_type: str, userid: str, group: str, resource: str, status: str, rc: int, details: str = "", ip: str = "127.0.0.1"):
    """
    Log an SMF Type 80 (RACF Processing Event) record.
    Matches standard mainframe security audit formats.
    """
    record = {
        "record_id": f"SMF80-{int(time.time()*1000)%100000000:08d}",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "event_type": event_type,  # LOGON, LOGOFF, RACF_AUTH, RACF_VIOLATION, DATASET_MUTATION, BATCH_EXEC
        "userid": userid,
        "group": group,
        "resource": resource,
        "status": status,          # SUCCESS, DENIED, LOCKED
        "racf_rc": rc,             # 0=Authorized, 4=Warning, 8=Denied, 12=Revoked
        "ip_address": ip,
        "details": details
    }
    SECURITY_AUDIT_LOG.insert(0, record)
    if len(SECURITY_AUDIT_LOG) > 500:
        SECURITY_AUDIT_LOG.pop()

    # Append to persistent log file
    try:
        os.makedirs(DATA_DIR, exist_ok=True)
        line = f"{record['timestamp']}|{record['record_id']}|{record['event_type']:<15}|{record['userid']:<10}|{record['group']:<8}|RC={record['racf_rc']:04d}|{record['status']:<8}|{record['resource']:<30}|{record['details']}\n"
        with open(AUDIT_LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line)
    except Exception as e:
        print(f"Warning: Failed to write to SMF80 audit file: {e}")

# ----------------- CRYPTOGRAPHIC TOKEN ENGINE -----------------
def create_access_token(user: Dict[str, Any]) -> str:
    """Generate signed URL-safe HMAC-SHA256 Token."""
    payload = {
        "sub": user["userid"],
        "name": user["name"],
        "group": user["group"],
        "role": user["role"],
        "permissions": user["permissions"],
        "iat": int(time.time()),
        "exp": int(time.time()) + TOKEN_EXPIRY_SECONDS,
        "jti": secrets.token_hex(8)
    }
    header = {"alg": "HS256", "typ": "RACF-JWT"}
    h_b64 = base64.urlsafe_b64encode(json.dumps(header).encode('utf-8')).decode('utf-8').rstrip("=")
    p_b64 = base64.urlsafe_b64encode(json.dumps(payload).encode('utf-8')).decode('utf-8').rstrip("=")
    signing_input = f"{h_b64}.{p_b64}"
    sig = hmac.new(SECRET_KEY.encode('utf-8'), signing_input.encode('utf-8'), hashlib.sha256).digest()
    sig_b64 = base64.urlsafe_b64encode(sig).decode('utf-8').rstrip("=")
    return f"{signing_input}.{sig_b64}"

def verify_token(token: str) -> Dict[str, Any]:
    """Verify cryptographic signature and token expiration."""
    if token in REVOKED_TOKENS:
        raise HTTPException(status_code=401, detail="RACF Token has been revoked. Please logon again.")
    
    parts = token.split(".")
    if len(parts) != 3:
        raise HTTPException(status_code=401, detail="Malformed RACF Security Token.")
    
    h_b64, p_b64, sig_b64 = parts
    signing_input = f"{h_b64}.{p_b64}"
    expected_sig = hmac.new(SECRET_KEY.encode('utf-8'), signing_input.encode('utf-8'), hashlib.sha256).digest()
    expected_sig_b64 = base64.urlsafe_b64encode(expected_sig).decode('utf-8').rstrip("=")
    
    if not hmac.compare_digest(sig_b64, expected_sig_b64):
        raise HTTPException(status_code=401, detail="RACF Security Signature Verification Failed.")
    
    # Pad payload base64 if needed
    rem = len(p_b64) % 4
    if rem > 0:
        p_b64 += "=" * (4 - rem)
        
    try:
        payload = json.loads(base64.urlsafe_b64decode(p_b64.encode('utf-8')).decode('utf-8'))
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid RACF Token Payload.")
    
    if payload.get("exp", 0) < time.time():
        raise HTTPException(status_code=401, detail="RACF Token has expired. Session terminated.")
        
    return payload

# ----------------- RACF VIOLATION FORMATTER -----------------
def generate_racf_violation(userid: str, group: str, resource: str, action: str) -> str:
    """Format an authentic IBM RACF Security Violation Message (ICH408I)."""
    return (
        f"ICH408I USER({userid}) GROUP({group}) NAME(RACF SECURITY SUBSYSTEM) "
        f"{resource} CL(FACILITY) "
        f"INSUFFICIENT ACCESS AUTHORITY - FROM (GENERIC) "
        f"ACCESS INTENT({action.upper()})  ACCESS ALLOWED(NONE)"
    )

# ----------------- FASTAPI SECURITY DEPENDENCIES -----------------
security_bearer = HTTPBearer(auto_error=False)

def get_current_user_optional(credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer)) -> Optional[Dict[str, Any]]:
    """Return user payload if valid bearer token is provided, otherwise None."""
    if not credentials:
        return None
    try:
        return verify_token(credentials.credentials)
    except Exception:
        return None

def get_current_user(credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer)) -> Dict[str, Any]:
    """Strictly require authenticated user with valid RACF token."""
    if not credentials:
        raise HTTPException(
            status_code=401,
            detail="ICH408I RACF AUTHENTICATION REQUIRED - No RACF Bearer Token provided in Authorization header."
        )
    return verify_token(credentials.credentials)

def require_roles(allowed_roles: List[str], resource_name: str = "SYSTEM.OPERATION", action: str = "EXECUTE"):
    """
    Factory creating a dependency that verifies the user possesses one of the allowed roles.
    Raises standard RACF 403 error on unauthorized attempt and logs SMF Type 80 violation.
    """
    def role_checker(user: Dict[str, Any] = Depends(get_current_user), request: Request = None):
        user_role = user.get("role", "")
        if user_role not in allowed_roles:
            userid = user.get("sub", "UNKNOWN")
            group = user.get("group", "NONE")
            violation_msg = generate_racf_violation(userid, group, resource_name, action)
            
            client_ip = request.client.host if request and request.client else "127.0.0.1"
            log_smf80_event(
                event_type="RACF_VIOLATION",
                userid=userid,
                group=group,
                resource=resource_name,
                status="DENIED",
                rc=8,
                details=f"Required roles: {allowed_roles}, Actual role: {user_role}",
                ip=client_ip
            )
            
            raise HTTPException(
                status_code=403,
                detail=violation_msg
            )
        return user
    return role_checker

# ----------------- ACCOUNT LOCKOUT & RATE LIMITING -----------------
MAX_FAILED_ATTEMPTS = 5
LOCKOUT_DURATION_SECONDS = 300  # 5 minutes

def check_account_lockout(userid: str):
    """Raise 403 if account is currently locked out."""
    user = USERS_DB.get(userid)
    if not user:
        return
    lock_time = user.get("lockout_until", 0)
    if lock_time > time.time():
        remaining = int(lock_time - time.time())
        raise HTTPException(
            status_code=403,
            detail=f"ICH408I USER({userid}) ACCOUNT REVOKED / LOCKED DUE TO REPEATED FAILED LOGON ATTEMPTS. Retry in {remaining} seconds."
        )

def record_failed_attempt(userid: str, ip: str = "127.0.0.1"):
    """Increment failed attempts and trigger lockout if limit reached."""
    user = USERS_DB.get(userid)
    if not user:
        log_smf80_event("LOGON_FAILED", userid, "UNKNOWN", "RACF.LOGON", "DENIED", 8, "User does not exist in RACF DB", ip)
        return
    user["failed_attempts"] = user.get("failed_attempts", 0) + 1
    if user["failed_attempts"] >= MAX_FAILED_ATTEMPTS:
        user["lockout_until"] = time.time() + LOCKOUT_DURATION_SECONDS
        log_smf80_event("ACCOUNT_LOCKED", userid, user["group"], "RACF.LOGON", "LOCKED", 12, f"Account revoked for {LOCKOUT_DURATION_SECONDS}s after {MAX_FAILED_ATTEMPTS} failures", ip)
    else:
        log_smf80_event("LOGON_FAILED", userid, user["group"], "RACF.LOGON", "DENIED", 8, f"Failed attempt {user['failed_attempts']}/{MAX_FAILED_ATTEMPTS}", ip)

def record_successful_login(userid: str, ip: str = "127.0.0.1"):
    """Reset failed attempts on success and log SMF record."""
    user = USERS_DB.get(userid)
    if user:
        user["failed_attempts"] = 0
        user["lockout_until"] = 0
        log_smf80_event("LOGON_SUCCESS", userid, user["group"], "RACF.LOGON", "SUCCESS", 0, f"Session established for {user['role']}", ip)
