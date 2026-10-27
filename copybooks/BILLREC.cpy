*> ================================================================*
*>  BILLREC.CPY - CALCULATED BILLING OUTPUT RECORD LAYOUT          *
*>  SEQUENTIAL RECORD (LENGTH 100 BYTES)                           *
*> ================================================================*
       01  BILL-RECORD.
           05  BILL-ID                 PIC X(12).
           05  BILL-SUB-ID             PIC X(10).
           05  BILL-CUST-ID            PIC X(10).
           05  BILL-PLAN-ID            PIC X(08).
           05  BILL-BASE-AMT           PIC 9(07)V99.
           05  BILL-DISC-PCT           PIC 9(02)V99.
           05  BILL-DISC-AMT           PIC 9(07)V99.
           05  BILL-TAX-AMT            PIC 9(07)V99.
           05  BILL-FINAL-AMT          PIC 9(07)V99.
           05  BILL-DATE               PIC X(10).
           05  FILLER                  PIC X(19).
