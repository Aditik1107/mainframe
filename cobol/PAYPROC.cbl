*> ================================================================
*> PROGRAM:    PAYPROC.CBL                                        *
*> TITLE:      PAYMENT MATCHING & VALIDATION PROGRAM              *
*> STEP:       STEP04 OF JOB SUBBILL01                            *
*> PURPOSE:    MATCHES PAYMENT TRANSACTIONS WITH GENERATED BILLS. *
*>             CLASSIFIES STATUS: SUCCESS, AMOUNT MISMATCH,       *
*>             FAILED PAYMENT, OR DUPLICATE TRANSACTION.          *
*>             WRITES SUCCESSFUL PAYMENTS TO PAYOUT.DAT.          *
*>             WRITES ALL NON-SUCCESS OUTCOMES TO EXCEPTION.DAT.  *
*> ================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAYPROC.
       AUTHOR. VIT-VU-TEAM.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-Z.
       OBJECT-COMPUTER. IBM-Z.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT BILL-FILE ASSIGN TO "data/BILLS.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-BILL-ST.

           SELECT PAY-FILE ASSIGN TO "data/PAYMENT.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-PAY-ST.

           SELECT PAYOUT-FILE ASSIGN TO "data/PAYOUT.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-PO-ST.

           SELECT EXCP-FILE ASSIGN TO "data/EXCEPTION.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-EXCP-ST.

       DATA DIVISION.
       FILE SECTION.
       FD  BILL-FILE.
       COPY "copybooks/BILLREC.cpy".

       FD  PAY-FILE.
       COPY "copybooks/PAYREC.cpy".

       FD  PAYOUT-FILE.
       COPY "copybooks/PAYOUTREC.cpy".

       FD  EXCP-FILE.
       COPY "copybooks/EXCPREC.cpy".

       WORKING-STORAGE SECTION.
*> File Statuses
       01  WS-FILE-STATUSES.
           05  WS-BILL-ST              PIC XX VALUE SPACES.
           05  WS-PAY-ST               PIC XX VALUE SPACES.
           05  WS-PO-ST                PIC XX VALUE SPACES.
           05  WS-EXCP-ST              PIC XX VALUE SPACES.

*> EOF Flags
       01  WS-FLAGS.
           05  WS-BILL-EOF             PIC X  VALUE 'N'.
           05  WS-PAY-EOF              PIC X  VALUE 'N'.
           05  WS-IS-DUPLICATE         PIC X  VALUE 'N'.
           05  WS-FOUND-BILL           PIC X  VALUE 'N'.

*> Exception Parameters
       01  WS-EXCP-PARMS.
           05  WS-EP-CODE              PIC X(06).
           05  WS-EP-DESC              PIC X(45).

*> Metrics & Counters
       01  WS-METRICS.
           05  WS-BILLS-LOADED         PIC 9(05) VALUE 0.
           05  WS-PAY-READ-COUNT       PIC 9(05) VALUE 0.
           05  WS-PAY-SUCCESS-COUNT    PIC 9(05) VALUE 0.
           05  WS-PAY-MISMATCH-COUNT   PIC 9(05) VALUE 0.
           05  WS-PAY-FAILED-COUNT     PIC 9(05) VALUE 0.
           05  WS-PAY-DUP-COUNT        PIC 9(05) VALUE 0.
           05  WS-TOTAL-RECV-AMT       PIC 9(09)V99 VALUE 0.

*> Timestamp Variables
       01  WS-DATETIME-DATA.
           05  WS-CURR-YEAR            PIC 9(04).
           05  WS-CURR-MONTH           PIC 9(02).
           05  WS-CURR-DAY             PIC 9(02).
           05  WS-CURR-HOUR            PIC 9(02).
           05  WS-CURR-MIN             PIC 9(02).
           05  WS-CURR-SEC             PIC 9(02).
           05  WS-TIMESTAMP-STR        PIC X(19).

*> In-Memory Bill Table
       01  WS-BILL-TABLE.
           05  WS-BILL-ROW OCCURS 100 TIMES INDEXED BY B-IDX.
               10  TB-B-BILL-ID        PIC X(12).
               10  TB-B-SUB-ID         PIC X(10).
               10  TB-B-FINAL-AMT      PIC 9(07)V99.
               10  TB-B-IS-PAID        PIC X(01) VALUE 'N'.

*> In-Memory Processed Txn Table for Duplicate Detection
       01  WS-TXN-HISTORY.
           05  WS-TXN-COUNT            PIC 9(03) VALUE 0.
           05  WS-TXN-ENTRY OCCURS 100 TIMES.
               10  TB-TXN-ID           PIC X(12).

       01  WS-IDX                      PIC 9(03) VALUE 0.
       01  WS-MATCHED-BILL-ID          PIC X(12).
       01  WS-EXPECTED-AMT             PIC 9(07)V99.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-BILLS
           PERFORM 3000-PROCESS-PAYMENTS
           PERFORM 4000-TERMINATE
           STOP RUN.

       1000-INITIALIZE.
           DISPLAY "=================================================="
           DISPLAY "PAYPROC: STEP04 - PAYMENT MATCHING & VALIDATION"
           DISPLAY "=================================================="

           MOVE FUNCTION CURRENT-DATE (1:4) TO WS-CURR-YEAR
           MOVE FUNCTION CURRENT-DATE (5:2) TO WS-CURR-MONTH
           MOVE FUNCTION CURRENT-DATE (7:2) TO WS-CURR-DAY
           MOVE FUNCTION CURRENT-DATE (9:2) TO WS-CURR-HOUR
           MOVE FUNCTION CURRENT-DATE (11:2) TO WS-CURR-MIN
           MOVE FUNCTION CURRENT-DATE (13:2) TO WS-CURR-SEC
           
           STRING WS-CURR-YEAR "-" WS-CURR-MONTH "-" WS-CURR-DAY
                  " " WS-CURR-HOUR ":" WS-CURR-MIN ":" WS-CURR-SEC
                  DELIMITED BY SIZE INTO WS-TIMESTAMP-STR

           OPEN INPUT BILL-FILE
           IF WS-BILL-ST NOT = "00"
               DISPLAY "PAYPROC ERROR: UNABLE TO OPEN BILLS ST=" WS-BILL-ST
               MOVE 8 TO RETURN-CODE
               STOP RUN
           END-IF

           OPEN INPUT PAY-FILE
           IF WS-PAY-ST NOT = "00"
               DISPLAY "PAYPROC ERROR: UNABLE TO OPEN PAYMENT ST=" WS-PAY-ST
               MOVE 8 TO RETURN-CODE
               STOP RUN
           END-IF

           OPEN OUTPUT PAYOUT-FILE
           IF WS-PO-ST NOT = "00"
               DISPLAY "PAYPROC ERROR: UNABLE TO OPEN PAYOUT ST=" WS-PO-ST
               MOVE 8 TO RETURN-CODE
               STOP RUN
           END-IF

           OPEN EXTEND EXCP-FILE
           IF WS-EXCP-ST NOT = "00"
               OPEN OUTPUT EXCP-FILE
           END-IF.

       2000-LOAD-BILLS.
           MOVE 'N' TO WS-BILL-EOF
           MOVE 0 TO WS-BILLS-LOADED
           PERFORM UNTIL WS-BILL-EOF = 'Y'
               READ BILL-FILE
                   AT END
                       MOVE 'Y' TO WS-BILL-EOF
                   NOT AT END
                       ADD 1 TO WS-BILLS-LOADED
                       MOVE BILL-ID TO TB-B-BILL-ID (WS-BILLS-LOADED)
                       MOVE BILL-SUB-ID TO TB-B-SUB-ID (WS-BILLS-LOADED)
                       MOVE BILL-FINAL-AMT TO TB-B-FINAL-AMT (WS-BILLS-LOADED)
                       MOVE 'N' TO TB-B-IS-PAID (WS-BILLS-LOADED)
               END-READ
           END-PERFORM
           CLOSE BILL-FILE
           DISPLAY "PAYPROC: LOADED " WS-BILLS-LOADED " BILLS FOR RECONCILIATION".

       3000-PROCESS-PAYMENTS.
           MOVE 'N' TO WS-PAY-EOF
           PERFORM UNTIL WS-PAY-EOF = 'Y'
               READ PAY-FILE
                   AT END
                       MOVE 'Y' TO WS-PAY-EOF
                   NOT AT END
                       ADD 1 TO WS-PAY-READ-COUNT
                       PERFORM 3100-EVALUATE-PAYMENT
               END-READ
           END-PERFORM.

       3100-EVALUATE-PAYMENT.
*> Check 324: Duplicate Transaction Check
           MOVE 'N' TO WS-IS-DUPLICATE
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-TXN-COUNT OR WS-IS-DUPLICATE = 'Y'
               IF TB-TXN-ID (WS-IDX) = PAY-TXN-ID
                   MOVE 'Y' TO WS-IS-DUPLICATE
               END-IF
           END-PERFORM

           IF WS-IS-DUPLICATE = 'Y'
               ADD 1 TO WS-PAY-DUP-COUNT
               MOVE "ERR010" TO WS-EP-CODE
               MOVE "DUPLICATE TRANSACTION ID DETECTED" TO WS-EP-DESC
               PERFORM 3300-WRITE-EXCEPTION
               EXIT PARAGRAPH
           END-IF

*> Record Transaction ID in history table
           ADD 1 TO WS-TXN-COUNT
           MOVE PAY-TXN-ID TO TB-TXN-ID (WS-TXN-COUNT)

*> Check 323: Gateway / Bank Status Failed
           IF PAY-STATUS(1:6) = "FAILED"
               ADD 1 TO WS-PAY-FAILED-COUNT
               MOVE "ERR011" TO WS-EP-CODE
               MOVE "PAYMENT GATEWAY REPORTED TRANSACTION FAILED" TO WS-EP-DESC
               PERFORM 3300-WRITE-EXCEPTION
               EXIT PARAGRAPH
           END-IF

*> Match with corresponding Bill using SUB-ID
           MOVE 'N' TO WS-FOUND-BILL
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-BILLS-LOADED OR WS-FOUND-BILL = 'Y'
               IF TB-B-SUB-ID (WS-IDX) = PAY-SUB-ID
                   MOVE 'Y' TO WS-FOUND-BILL
                   MOVE TB-B-BILL-ID (WS-IDX) TO WS-MATCHED-BILL-ID
                   MOVE TB-B-FINAL-AMT (WS-IDX) TO WS-EXPECTED-AMT
               END-IF
           END-PERFORM

           IF WS-FOUND-BILL = 'N'
               MOVE "ERR012" TO WS-EP-CODE
               MOVE "NO MATCHING BILL FOUND FOR SUBSCRIPTION" TO WS-EP-DESC
               PERFORM 3300-WRITE-EXCEPTION
               EXIT PARAGRAPH
           END-IF

*> Check 321 vs 322: Amount Comparison
           IF PAY-AMOUNT < WS-EXPECTED-AMT
*> Rule 322: Amount Mismatch (Underpayment)
               ADD 1 TO WS-PAY-MISMATCH-COUNT
               MOVE "ERR013" TO WS-EP-CODE
               MOVE "AMOUNT MISMATCH: PAID LESS THAN BILLED AMT" TO WS-EP-DESC
               PERFORM 3300-WRITE-EXCEPTION
           ELSE
*> Rule 321: SUCCESS (Payment matches or fulfills bill)
               ADD 1 TO WS-PAY-SUCCESS-COUNT
               ADD PAY-AMOUNT TO WS-TOTAL-RECV-AMT
               PERFORM 3200-WRITE-PAYOUT
           END-IF.

       3200-WRITE-PAYOUT.
           MOVE SPACES TO PAYMENT-OUT-RECORD
           MOVE PAY-TXN-ID TO PO-TXN-ID
           MOVE WS-MATCHED-BILL-ID TO PO-BILL-ID
           MOVE PAY-SUB-ID TO PO-SUB-ID
           MOVE PAY-AMOUNT TO PO-PAID-AMT
           MOVE PAY-DATE TO PO-PAY-DATE
           MOVE PAY-MODE TO PO-PAY-MODE
           MOVE "SUCCESS   " TO PO-STATUS
           WRITE PAYMENT-OUT-RECORD.

       3300-WRITE-EXCEPTION.
           MOVE SPACES TO EXCEPTION-RECORD
           MOVE "PAYPROC " TO EXCP-SOURCE-STEP
           MOVE PAY-TXN-ID TO EXCP-RECORD-KEY
           MOVE WS-EP-CODE TO EXCP-ERR-CODE
           MOVE WS-EP-DESC TO EXCP-ERR-DESC
           MOVE WS-TIMESTAMP-STR TO EXCP-TIMESTAMP
           WRITE EXCEPTION-RECORD.

       4000-TERMINATE.
           CLOSE PAY-FILE
           CLOSE PAYOUT-FILE
           CLOSE EXCP-FILE

           DISPLAY "--------------------------------------------------"
           DISPLAY "PAYPROC EXECUTION SUMMARY:"
           DISPLAY "  TOTAL TRANSACTIONS PROCESSED: " WS-PAY-READ-COUNT
           DISPLAY "  SUCCESSFUL PAYMENTS:          " WS-PAY-SUCCESS-COUNT
           DISPLAY "  AMOUNT MISMATCH EXCEPTIONS:   " WS-PAY-MISMATCH-COUNT
           DISPLAY "  FAILED TRANSACTION ATTEMPTS:  " WS-PAY-FAILED-COUNT
           DISPLAY "  DUPLICATE TRANSACTIONS:       " WS-PAY-DUP-COUNT
           DISPLAY "  TOTAL REVENUE COLLECTED:      " WS-TOTAL-RECV-AMT
           DISPLAY "--------------------------------------------------"

           IF (WS-PAY-MISMATCH-COUNT + WS-PAY-FAILED-COUNT + WS-PAY-DUP-COUNT) > 0
               DISPLAY "PAYPROC: COND CODE SET TO 0004 (WARNING/EXCEPTIONS)"
               MOVE 4 TO RETURN-CODE
           ELSE
               DISPLAY "PAYPROC: COND CODE SET TO 0000 (NORMAL)"
               MOVE 0 TO RETURN-CODE
           END-IF.
