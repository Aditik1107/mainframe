#!/usr/bin/env python3
"""
Mainframe Batch Execution Engine / JCL Job Emulator
Simulates MVS JES2 Job SUBBILL01 execution of COBOL programs:
STEP01: IDCAMS (Dataset Allocation & Purge)
STEP02: SUBVAL (Validation)
STEP03: BILLPROC (Billing Engine)
STEP04: PAYPROC (Payment Matching)
STEP05: REVPROC (Revenue Aggregation)
STEP06: REPORT (Spool Generation)
STEP07: ARCHIVE / SPOOL (Dispatch)
"""

import os
import sys
import time
import subprocess
from datetime import datetime

def run_job(job_id="JOB04821", job_name="SUBBILL01"):
    print("=" * 80)
    print(f"  JES2 JOB INITIATOR - {job_name} ({job_id})")
    print(f"  SYSTEM: IBM z16 / Enterprise MVS Batch Subsystem")
    print(f"  START TIME: {datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]}")
    print("=" * 80)

    # Setup environment
    env = os.environ.copy()
    env['PATH'] = r'C:\msys64\mingw64\bin;' + env.get('PATH', '')

    spool_log = []
    
    def log(msg):
        print(msg)
        spool_log.append(msg)

    log(f"10.00.00 JOB {job_id} $HASP373 {job_name} STARTED - INIT 01 - CLASS A - SYS ZOS1")

    # STEP01: IDCAMS
    log(f"10.00.01 JOB {job_id} //STEP01 EXEC PGM=IDCAMS")
    # Clean output files
    for f in ['VALIDSUB.DAT', 'BILLS.DAT', 'PAYOUT.DAT', 'REVENUE.DAT', 'EXCEPTION.DAT',
              'BILLRPT.TXT', 'REVRPT.TXT', 'EXCPRPT.TXT']:
        p = os.path.join('data', f)
        if os.path.exists(p):
            os.remove(p)
    log(f"10.00.02 JOB {job_id} - STEP01 IDCAMS COMPLETED - RC=0000")

    steps = [
        ("STEP02", "SUBVAL", "bin/SUBVAL.exe"),
        ("STEP03", "BILLPROC", "bin/BILLPROC.exe"),
        ("STEP04", "PAYPROC", "bin/PAYPROC.exe"),
        ("STEP05", "REVPROC", "bin/REVPROC.exe"),
        ("STEP06", "REPORT", "bin/REPORT.exe")
    ]

    max_rc = 0
    step_results = {}

    for step_num, pgm_name, exe_path in steps:
        log(f"{datetime.now().strftime('%H.%M.%S')} JOB {job_id} //{step_num} EXEC PGM={pgm_name}")
        
        if not os.path.exists(exe_path):
            log(f"  [ABEND] PROGRAM {exe_path} NOT FOUND! S806-04 ABEND")
            return {"status": "ABEND", "max_rc": 12, "log": spool_log}

        start_t = time.time()
        res = subprocess.run([exe_path], capture_output=True, text=True, env=env)
        elapsed = time.time() - start_t
        rc = res.returncode
        if rc > max_rc:
            max_rc = rc

        step_results[step_num] = {
            "program": pgm_name,
            "rc": rc,
            "stdout": res.stdout,
            "stderr": res.stderr,
            "elapsed_ms": int(elapsed * 1000)
        }

        # Print program stdout
        for line in res.stdout.strip().split("\n"):
            if line:
                log(f"  | {line}")

        if rc <= 4:
            log(f"{datetime.now().strftime('%H.%M.%S')} JOB {job_id} - {step_num} {pgm_name} COMPLETED - COND CODE {rc:04d} (ELAPSED {elapsed:.2f}s)")
        else:
            log(f"{datetime.now().strftime('%H.%M.%S')} JOB {job_id} - {step_num} {pgm_name} TERMINATED WITH COND CODE {rc:04d} - STEP COND CHECK FAILED")
            break

    # STEP07: Spool Archive
    if max_rc <= 4:
        log(f"{datetime.now().strftime('%H.%M.%S')} JOB {job_id} //STEP07 EXEC PGM=IEBGENER,COND=(4,LT)")
        log(f"{datetime.now().strftime('%H.%M.%S')} JOB {job_id} - STEP07 ARCHIVE SPOOL COMPLETED - RC=0000")
        log(f"{datetime.now().strftime('%H.%M.%S')} JOB {job_id} $HASP395 {job_name} ENDED - MAX CC={max_rc:04d} - NORMAL TERMINATION")
    else:
        log(f"{datetime.now().strftime('%H.%M.%S')} JOB {job_id} $HASP395 {job_name} ENDED - HIGHEST COND CODE {max_rc:04d} - ABORTED")

    print("=" * 80)
    print(f"  BATCH RUN COMPLETE. MAX RETURN CODE: {max_rc:04d}")
    print("=" * 80)
    return {"status": "SUCCESS" if max_rc <= 4 else "FAILED", "max_rc": max_rc, "step_results": step_results, "log": spool_log}

if __name__ == "__main__":
    run_job()
