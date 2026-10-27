*> ================================================================*
*>  SUBREC.CPY - SUBSCRIPTION MASTER RECORD LAYOUT                 *
*>  VSAM KSDS KEY: SUB-ID (LENGTH 10, OFFSET 0)                    *
*>  TOTAL RECORD LENGTH: 80 BYTES                                  *
*> ================================================================*
       01  SUBSCRIPTION-RECORD.
           05  SUB-ID                  PIC X(10).
           05  SUB-CUST-ID             PIC X(10).
           05  SUB-PLAN-ID             PIC X(08).
           05  SUB-START-DATE          PIC X(10).
           05  SUB-END-DATE            PIC X(10).
           05  SUB-DURATION-MONTHS     PIC 9(03).
           05  SUB-STATUS              PIC X(01).
               88  SUB-ACTIVE          VALUE 'A'.
               88  SUB-CANCELLED       VALUE 'C'.
               88  SUB-EXPIRED         VALUE 'E'.
           05  SUB-NEXT-BILL-DATE      PIC X(10).
           05  FILLER                  PIC X(18).
