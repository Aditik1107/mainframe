*> ================================================================*
*>  REVREC.CPY - REVENUE SUMMARY RECORD LAYOUT                     *
*>  SEQUENTIAL RECORD (LENGTH 80 BYTES)                            *
*> ================================================================*
       01  REVENUE-RECORD.
           05  REV-PLAN-ID             PIC X(08).
           05  REV-PLAN-NAME           PIC X(25).
           05  REV-SUB-COUNT           PIC 9(05).
           05  REV-BILLED-AMT          PIC 9(09)V99.
           05  REV-RECEIVED-AMT        PIC 9(09)V99.
           05  REV-OUTSTAND-AMT        PIC 9(09)V99.
           05  FILLER                  PIC X(09).
