*> ================================================================*
*>  PAYOUTREC.CPY - VERIFIED PAYMENT OUTPUT RECORD LAYOUT          *
*>  SEQUENTIAL RECORD (LENGTH 80 BYTES)                            *
*> ================================================================*
       01  PAYMENT-OUT-RECORD.
           05  PO-TXN-ID               PIC X(12).
           05  PO-BILL-ID              PIC X(12).
           05  PO-SUB-ID               PIC X(10).
           05  PO-PAID-AMT             PIC 9(07)V99.
           05  PO-PAY-DATE             PIC X(10).
           05  PO-PAY-MODE             PIC X(15).
           05  PO-STATUS               PIC X(10).
           05  FILLER                  PIC X(02).
