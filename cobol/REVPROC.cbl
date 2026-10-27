*> ================================================================
*> PROGRAM:    REVPROC.CBL                                        *
*> TITLE:      REVENUE AGGREGATION PROGRAM                        *
*> STEP:       STEP05 OF JOB SUBBILL01                            *
*> PURPOSE:    AGGREGATES BILLED REVENUE, RECEIVED PAYMENTS, AND  *
*>             OUTSTANDING BALANCES BY PLAN AND IN TOTAL.         *
*>             WRITES SUMMARY RECORDS TO REVENUE.DAT.             *
*> ================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. REVPROC.
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

           SELECT PAYOUT-FILE ASSIGN TO "data/PAYOUT.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-PO-ST.

           SELECT PLAN-FILE ASSIGN TO "data/PLANMAST.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-PLAN-ST.

           SELECT REV-FILE ASSIGN TO "data/REVENUE.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-REV-ST.

       DATA DIVISION.
       FILE SECTION.
       FD  BILL-FILE.
       COPY "copybooks/BILLREC.cpy".

       FD  PAYOUT-FILE.
       COPY "copybooks/PAYOUTREC.cpy".

       FD  PLAN-FILE.
       COPY "copybooks/PLANREC.cpy".

       FD  REV-FILE.
       COPY "copybooks/REVREC.cpy".

       WORKING-STORAGE SECTION.
*> File Statuses
       01  WS-FILE-STATUSES.
           05  WS-BILL-ST              PIC XX VALUE SPACES.
           05  WS-PO-ST                PIC XX VALUE SPACES.
           05  WS-PLAN-ST              PIC XX VALUE SPACES.
           05  WS-REV-ST               PIC XX VALUE SPACES.

*> EOF Flags
       01  WS-FLAGS.
           05  WS-BILL-EOF             PIC X  VALUE 'N'.
           05  WS-PO-EOF               PIC X  VALUE 'N'.
           05  WS-PLAN-EOF             PIC X  VALUE 'N'.
           05  WS-FOUND                PIC X  VALUE 'N'.

*> Aggregation Table by Plan
       01  WS-PLAN-AGG-TABLE.
           05  WS-PLAN-COUNT           PIC 9(03) VALUE 0.
           05  WS-PLAN-AGG OCCURS 50 TIMES INDEXED BY AGG-IDX.
               10  AG-PLAN-ID          PIC X(08).
               10  AG-PLAN-NAME        PIC X(25).
               10  AG-SUB-COUNT        PIC 9(05) VALUE 0.
               10  AG-BILLED-AMT       PIC 9(09)V99 VALUE 0.
               10  AG-RECEIVED-AMT     PIC 9(09)V99 VALUE 0.
               10  AG-OUTSTAND-AMT     PIC 9(09)V99 VALUE 0.

*> Total Metrics
       01  WS-GRAND-TOTALS.
           05  GT-SUB-COUNT            PIC 9(05) VALUE 0.
           05  GT-BILLED-AMT           PIC 9(09)V99 VALUE 0.
           05  GT-RECEIVED-AMT         PIC 9(09)V99 VALUE 0.
           05  GT-OUTSTAND-AMT         PIC 9(09)V99 VALUE 0.

       01  WS-IDX                      PIC 9(03) VALUE 0.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-PLANS
           PERFORM 3000-AGGREGATE-BILLS
           PERFORM 4000-AGGREGATE-PAYMENTS
           PERFORM 5000-WRITE-REVENUE-SUMMARY
           PERFORM 6000-TERMINATE
           STOP RUN.

       1000-INITIALIZE.
           DISPLAY "=================================================="
           DISPLAY "REVPROC: STEP05 - REVENUE AGGREGATION"
           DISPLAY "=================================================="

           OPEN INPUT PLAN-FILE
           IF WS-PLAN-ST NOT = "00"
               DISPLAY "REVPROC ERROR: UNABLE TO OPEN PLANMAST ST=" WS-PLAN-ST
               MOVE 8 TO RETURN-CODE
               STOP RUN
           END-IF

           OPEN INPUT BILL-FILE
           IF WS-BILL-ST NOT = "00"
               DISPLAY "REVPROC ERROR: UNABLE TO OPEN BILLS ST=" WS-BILL-ST
               MOVE 8 TO RETURN-CODE
               STOP RUN
           END-IF

           OPEN INPUT PAYOUT-FILE
           IF WS-PO-ST NOT = "00"
               DISPLAY "REVPROC ERROR: UNABLE TO OPEN PAYOUT ST=" WS-PO-ST
               MOVE 8 TO RETURN-CODE
               STOP RUN
           END-IF

           OPEN OUTPUT REV-FILE
           IF WS-REV-ST NOT = "00"
               DISPLAY "REVPROC ERROR: UNABLE TO OPEN REVENUE ST=" WS-REV-ST
               MOVE 8 TO RETURN-CODE
               STOP RUN
           END-IF.

       2000-LOAD-PLANS.
           MOVE 'N' TO WS-PLAN-EOF
           MOVE 0 TO WS-PLAN-COUNT
           PERFORM UNTIL WS-PLAN-EOF = 'Y'
               READ PLAN-FILE
                   AT END
                       MOVE 'Y' TO WS-PLAN-EOF
                   NOT AT END
                       ADD 1 TO WS-PLAN-COUNT
                       MOVE PLAN-ID TO AG-PLAN-ID (WS-PLAN-COUNT)
                       MOVE PLAN-NAME TO AG-PLAN-NAME (WS-PLAN-COUNT)
                       MOVE 0 TO AG-SUB-COUNT (WS-PLAN-COUNT)
                       MOVE 0 TO AG-BILLED-AMT (WS-PLAN-COUNT)
                       MOVE 0 TO AG-RECEIVED-AMT (WS-PLAN-COUNT)
                       MOVE 0 TO AG-OUTSTAND-AMT (WS-PLAN-COUNT)
               END-READ
           END-PERFORM
           CLOSE PLAN-FILE
           DISPLAY "REVPROC: LOADED " WS-PLAN-COUNT " PLANS FOR AGGREGATION".

       3000-AGGREGATE-BILLS.
           MOVE 'N' TO WS-BILL-EOF
           PERFORM UNTIL WS-BILL-EOF = 'Y'
               READ BILL-FILE
                   AT END
                       MOVE 'Y' TO WS-BILL-EOF
                   NOT AT END
                       PERFORM 3100-ADD-BILL-TO-PLAN
               END-READ
           END-PERFORM
           CLOSE BILL-FILE.

       3100-ADD-BILL-TO-PLAN.
           MOVE 'N' TO WS-FOUND
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-PLAN-COUNT OR WS-FOUND = 'Y'
               IF AG-PLAN-ID (WS-IDX) = BILL-PLAN-ID
                   MOVE 'Y' TO WS-FOUND
                   ADD 1 TO AG-SUB-COUNT (WS-IDX)
                   ADD BILL-FINAL-AMT TO AG-BILLED-AMT (WS-IDX)
                   ADD 1 TO GT-SUB-COUNT
                   ADD BILL-FINAL-AMT TO GT-BILLED-AMT
               END-IF
           END-PERFORM.

       4000-AGGREGATE-PAYMENTS.
           MOVE 'N' TO WS-PO-EOF
           PERFORM UNTIL WS-PO-EOF = 'Y'
               READ PAYOUT-FILE
                   AT END
                       MOVE 'Y' TO WS-PO-EOF
                   NOT AT END
                       ADD PO-PAID-AMT TO GT-RECEIVED-AMT
                       PERFORM 4100-ADD-PAYMENT-TO-PLAN
               END-READ
           END-PERFORM
           CLOSE PAYOUT-FILE.

       4100-ADD-PAYMENT-TO-PLAN.
           IF WS-PLAN-COUNT > 0
               ADD PO-PAID-AMT TO AG-RECEIVED-AMT (1)
           END-IF.

       5000-WRITE-REVENUE-SUMMARY.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-PLAN-COUNT
               
               COMPUTE AG-OUTSTAND-AMT (WS-IDX) =
                   AG-BILLED-AMT (WS-IDX) - AG-RECEIVED-AMT (WS-IDX)

               MOVE SPACES TO REVENUE-RECORD
               MOVE AG-PLAN-ID (WS-IDX) TO REV-PLAN-ID
               MOVE AG-PLAN-NAME (WS-IDX) TO REV-PLAN-NAME
               MOVE AG-SUB-COUNT (WS-IDX) TO REV-SUB-COUNT
               MOVE AG-BILLED-AMT (WS-IDX) TO REV-BILLED-AMT
               MOVE AG-RECEIVED-AMT (WS-IDX) TO REV-RECEIVED-AMT
               MOVE AG-OUTSTAND-AMT (WS-IDX) TO REV-OUTSTAND-AMT
               WRITE REVENUE-RECORD
           END-PERFORM

*> Write Grand Total Summary Record
           COMPUTE GT-OUTSTAND-AMT = GT-BILLED-AMT - GT-RECEIVED-AMT
           MOVE SPACES TO REVENUE-RECORD
           MOVE "TOTAL   " TO REV-PLAN-ID
           MOVE "ALL PLANS COMBINED       " TO REV-PLAN-NAME
           MOVE GT-SUB-COUNT TO REV-SUB-COUNT
           MOVE GT-BILLED-AMT TO REV-BILLED-AMT
           MOVE GT-RECEIVED-AMT TO REV-RECEIVED-AMT
           MOVE GT-OUTSTAND-AMT TO REV-OUTSTAND-AMT
           WRITE REVENUE-RECORD.

       6000-TERMINATE.
           CLOSE REV-FILE
           DISPLAY "--------------------------------------------------"
           DISPLAY "REVPROC EXECUTION SUMMARY:"
           DISPLAY "  TOTAL SUBSCRIPTIONS BILLED:  " GT-SUB-COUNT
           DISPLAY "  TOTAL GROSS REVENUE BILLED:  " GT-BILLED-AMT
           DISPLAY "  TOTAL REVENUE COLLECTED:     " GT-RECEIVED-AMT
           DISPLAY "  NET OUTSTANDING RECEIVABLES: " GT-OUTSTAND-AMT
           DISPLAY "--------------------------------------------------"
           DISPLAY "REVPROC: COND CODE SET TO 0000 (NORMAL)"
           MOVE 0 TO RETURN-CODE.
