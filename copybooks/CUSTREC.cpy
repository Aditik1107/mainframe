*> ================================================================*
*>  CUSTREC.CPY - CUSTOMER MASTER RECORD LAYOUT                    *
*>  VSAM KSDS KEY: CUST-ID (LENGTH 10, OFFSET 0)                   *
*>  TOTAL RECORD LENGTH: 100 BYTES                                 *
*> ================================================================*
       01  CUSTOMER-RECORD.
           05  CUST-ID                 PIC X(10).
           05  CUST-NAME               PIC X(30).
           05  CUST-EMAIL              PIC X(30).
           05  CUST-PHONE              PIC X(15).
           05  CUST-STATUS             PIC X(01).
               88  CUST-ACTIVE         VALUE 'A'.
               88  CUST-INACTIVE       VALUE 'I'.
               88  CUST-SUSPENDED      VALUE 'S'.
           05  CUST-CREATED-DATE       PIC X(10).
           05  FILLER                  PIC X(04).
