*> ================================================================*
*>  VALIDSUB.CPY - VALIDATED SUBSCRIPTION RECORD LAYOUT            *
*>  SEQUENTIAL RECORD (LENGTH 80 BYTES)                            *
*> ================================================================*
       01  VALID-SUB-RECORD.
           05  VAL-SUB-ID              PIC X(10).
           05  VAL-CUST-ID             PIC X(10).
           05  VAL-CUST-NAME           PIC X(30).
           05  VAL-PLAN-ID             PIC X(08).
           05  VAL-DURATION-MONTHS     PIC 9(03).
           05  VAL-BILL-DATE           PIC X(10).
           05  FILLER                  PIC X(09).
