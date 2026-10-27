*> ================================================================*
*>  PAYREC.CPY - PAYMENT TRANSACTION INPUT RECORD LAYOUT           *
*>  SEQUENTIAL RECORD (LENGTH 80 BYTES)                            *
*> ================================================================*
       01  PAYMENT-RECORD.
           05  PAY-TXN-ID              PIC X(12).
           05  PAY-SUB-ID              PIC X(10).
           05  PAY-AMOUNT              PIC 9(07)V99.
           05  PAY-DATE                PIC X(10).
           05  PAY-MODE                PIC X(15).
           05  PAY-STATUS              PIC X(10).
               88  PAY-STAT-SUCCESS    VALUE 'SUCCESS   '.
               88  PAY-STAT-FAILED     VALUE 'FAILED    '.
               88  PAY-STAT-PENDING    VALUE 'PENDING   '.
           05  FILLER                  PIC X(14).
