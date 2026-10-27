*> ================================================================*
*>  PLANREC.CPY - PLAN MASTER RECORD LAYOUT                        *
*>  VSAM KSDS KEY: PLAN-ID (LENGTH 8, OFFSET 0)                    *
*>  TOTAL RECORD LENGTH: 60 BYTES                                  *
*> ================================================================*
       01  PLAN-RECORD.
           05  PLAN-ID                 PIC X(08).
           05  PLAN-NAME               PIC X(25).
           05  PLAN-BASE-AMOUNT        PIC 9(07)V99.
           05  PLAN-BILL-CYCLE         PIC X(01).
               88  CYCLE-MONTHLY       VALUE 'M'.
               88  CYCLE-QUARTERLY     VALUE 'Q'.
               88  CYCLE-ANNUAL        VALUE 'A'.
           05  PLAN-STATUS             PIC X(01).
               88  PLAN-ACTIVE         VALUE 'A'.
               88  PLAN-INACTIVE       VALUE 'I'.
           05  FILLER                  PIC X(16).
