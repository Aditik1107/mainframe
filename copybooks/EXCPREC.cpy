*> ================================================================*
*>  EXCPREC.CPY - EXCEPTION OUTPUT RECORD LAYOUT                   *
*>  SEQUENTIAL RECORD (LENGTH 100 BYTES)                           *
*> ================================================================*
       01  EXCEPTION-RECORD.
           05  EXCP-SOURCE-STEP        PIC X(08).
           05  EXCP-RECORD-KEY         PIC X(12).
           05  EXCP-ERR-CODE           PIC X(06).
           05  EXCP-ERR-DESC           PIC X(45).
           05  EXCP-TIMESTAMP          PIC X(19).
           05  FILLER                  PIC X(10).
