*> ================================================================
*> PROGRAM:    BILLPROC.CBL                                       *
*> TITLE:      SUBSCRIPTION BILLING CALCULATION ENGINE            *
*> STEP:       STEP03 OF JOB SUBBILL01                            *
*> PURPOSE:    READS VALIDATED SUBSCRIPTIONS AND PLAN MASTER.     *
*>             APPLIES DURATION-BASED DISCOUNT AND 18% TAX.       *
*>             CALCULATES FINAL BILL AMOUNT AND WRITES BILLS.DAT. *
*> ================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BILLPROC.
       AUTHOR. VIT-VU-TEAM.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-Z.
       OBJECT-COMPUTER. IBM-Z.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT VALID-FILE ASSIGN TO "data/VALIDSUB.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-VAL-ST.

           SELECT PLAN-FILE ASSIGN TO "data/PLANMAST.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-PLAN-ST.

           SELECT BILL-FILE ASSIGN TO "data/BILLS.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-BILL-ST.

       DATA DIVISION.
       FILE SECTION.
       FD  VALID-FILE.
       COPY "copybooks/VALIDSUB.cpy".

       FD  PLAN-FILE.
       COPY "copybooks/PLANREC.cpy".

       FD  BILL-FILE.
       COPY "copybooks/BILLREC.cpy".

       WORKING-STORAGE SECTION.
*> File Statuses
       01  WS-FILE-STATUSES.
           05  WS-VAL-ST               PIC XX VALUE SPACES.
           05  WS-PLAN-ST              PIC XX VALUE SPACES.
           05  WS-BILL-ST              PIC XX VALUE SPACES.

*> EOF Flags
       01  WS-FLAGS.
           05  WS-VAL-EOF              PIC X  VALUE 'N'.
           05  WS-PLAN-EOF             PIC X  VALUE 'N'.

*> Counters & Totals
       01  WS-METRICS.
           05  WS-VALID-IN-COUNT       PIC 9(05) VALUE 0.
           05  WS-BILLS-GEN-COUNT      PIC 9(05) VALUE 0.
           05  WS-TOTAL-BASE-AMT       PIC 9(09)V99 VALUE 0.
           05  WS-TOTAL-DISC-AMT       PIC 9(09)V99 VALUE 0.
           05  WS-TOTAL-TAX-AMT        PIC 9(09)V99 VALUE 0.
           05  WS-TOTAL-FINAL-AMT      PIC 9(09)V99 VALUE 0.

*> Calculation Variables
       01  WS-CALC-VARS.
           05  WS-BASE-AMT             PIC 9(07)V99.
           05  WS-DISC-PCT             PIC 9(02)V99.
           05  WS-DISC-AMT             PIC 9(07)V99.
           05  WS-DISCOUNTED-BASE      PIC 9(07)V99.
           05  WS-TAX-AMT              PIC 9(07)V99.
           05  WS-FINAL-AMT            PIC 9(07)V99.
           05  WS-TAX-RATE             PIC V99 VALUE .18.
           05  WS-BILL-SEQ             PIC 9(04) VALUE 0.
           05  WS-BILL-ID-GEN          PIC X(12).

*> In-Memory Plan Master Table
       01  WS-PLAN-TBL-SIZE            PIC 9(03) VALUE 0.
       01  WS-IDX                      PIC 9(03) VALUE 0.
       01  WS-FOUND-PLAN               PIC X VALUE 'N'.

       01  WS-PLAN-TABLE.
           05  WS-PLAN-ROW OCCURS 50 TIMES INDEXED BY P-IDX.
               10  TB-P-ID             PIC X(08).
               10  TB-P-NAME           PIC X(25).
               10  TB-P-BASE           PIC 9(07)V99.

       01  WS-DATE-FORMAT.
           05  WS-Y                    PIC 9(04).
           05  WS-M                    PIC 9(02).
           05  WS-D                    PIC 9(02).

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-PLANS
           PERFORM 3000-PROCESS-BILLS
           PERFORM 4000-TERMINATE
           STOP RUN.

       1000-INITIALIZE.
           DISPLAY "=================================================="
           DISPLAY "BILLPROC: STEP03 - BILLING CALCULATION ENGINE"
           DISPLAY "=================================================="

           OPEN INPUT VALID-FILE
           IF WS-VAL-ST NOT = "00"
               DISPLAY "BILLPROC ERROR: UNABLE TO OPEN VALIDSUB ST=" WS-VAL-ST
               MOVE 8 TO RETURN-CODE
               STOP RUN
           END-IF

           OPEN INPUT PLAN-FILE
           IF WS-PLAN-ST NOT = "00"
               DISPLAY "BILLPROC ERROR: UNABLE TO OPEN PLANMAST ST=" WS-PLAN-ST
               MOVE 8 TO RETURN-CODE
               STOP RUN
           END-IF

           OPEN OUTPUT BILL-FILE
           IF WS-BILL-ST NOT = "00"
               DISPLAY "BILLPROC ERROR: UNABLE TO OPEN BILLS ST=" WS-BILL-ST
               MOVE 8 TO RETURN-CODE
               STOP RUN
           END-IF.

       2000-LOAD-PLANS.
           MOVE 'N' TO WS-PLAN-EOF
           MOVE 0 TO WS-PLAN-TBL-SIZE
           PERFORM UNTIL WS-PLAN-EOF = 'Y'
               READ PLAN-FILE
                   AT END
                       MOVE 'Y' TO WS-PLAN-EOF
                   NOT AT END
                       ADD 1 TO WS-PLAN-TBL-SIZE
                       MOVE PLAN-ID TO TB-P-ID (WS-PLAN-TBL-SIZE)
                       MOVE PLAN-NAME TO TB-P-NAME (WS-PLAN-TBL-SIZE)
                       MOVE PLAN-BASE-AMOUNT TO TB-P-BASE (WS-PLAN-TBL-SIZE)
               END-READ
           END-PERFORM
           CLOSE PLAN-FILE
           DISPLAY "BILLPROC: LOADED " WS-PLAN-TBL-SIZE " PLAN PRICING TIERS".

       3000-PROCESS-BILLS.
           MOVE 'N' TO WS-VAL-EOF
           PERFORM UNTIL WS-VAL-EOF = 'Y'
               READ VALID-FILE
                   AT END
                       MOVE 'Y' TO WS-VAL-EOF
                   NOT AT END
                       ADD 1 TO WS-VALID-IN-COUNT
                       PERFORM 3100-CALCULATE-BILL
               END-READ
           END-PERFORM.

       3100-CALCULATE-BILL.
           MOVE 'N' TO WS-FOUND-PLAN
           MOVE 0 TO WS-BASE-AMT

*> Lookup Plan Base Amount (Rule 311)
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-PLAN-TBL-SIZE OR WS-FOUND-PLAN = 'Y'
               IF TB-P-ID (WS-IDX) = VAL-PLAN-ID
                   MOVE 'Y' TO WS-FOUND-PLAN
                   MOVE TB-P-BASE (WS-IDX) TO WS-BASE-AMT
               END-IF
           END-PERFORM

           IF WS-FOUND-PLAN = 'N'
               MOVE 499.00 TO WS-BASE-AMT
           END-IF

*> Rule 312: Determine Duration Discount Band
*> 3 to 6 months: 5%
*> 7 to 12 months: 10%
*> > 12 months: 15%
*> < 3 months: 0%
           IF VAL-DURATION-MONTHS >= 3 AND VAL-DURATION-MONTHS <= 6
               MOVE 05.00 TO WS-DISC-PCT
           ELSE
               IF VAL-DURATION-MONTHS >= 7 AND VAL-DURATION-MONTHS <= 12
                   MOVE 10.00 TO WS-DISC-PCT
               ELSE
                   IF VAL-DURATION-MONTHS > 12
                       MOVE 15.00 TO WS-DISC-PCT
                   ELSE
                       MOVE 00.00 TO WS-DISC-PCT
                   END-IF
               END-IF
           END-IF

*> Compute Discount Amount
           COMPUTE WS-DISC-AMT ROUNDED =
               WS-BASE-AMT * (WS-DISC-PCT / 100)

*> Net base after discount
           COMPUTE WS-DISCOUNTED-BASE =
               WS-BASE-AMT - WS-DISC-AMT

*> Rule 313: Compute Tax (18% on discounted amount)
           COMPUTE WS-TAX-AMT ROUNDED =
               WS-DISCOUNTED-BASE * WS-TAX-RATE

*> Rule 314: Compute Final Bill Amount
           COMPUTE WS-FINAL-AMT =
               WS-DISCOUNTED-BASE + WS-TAX-AMT

*> Generate Bill ID: BIL + YYYYMMDD + SEQ
           ADD 1 TO WS-BILL-SEQ
           MOVE FUNCTION CURRENT-DATE (1:4) TO WS-Y
           MOVE FUNCTION CURRENT-DATE (5:2) TO WS-M
           MOVE FUNCTION CURRENT-DATE (7:2) TO WS-D

           STRING "BIL" WS-Y WS-M WS-D WS-BILL-SEQ
               DELIMITED BY SIZE INTO WS-BILL-ID-GEN

*> Populate Bill Record
           MOVE SPACES TO BILL-RECORD
           MOVE WS-BILL-ID-GEN TO BILL-ID
           MOVE VAL-SUB-ID TO BILL-SUB-ID
           MOVE VAL-CUST-ID TO BILL-CUST-ID
           MOVE VAL-PLAN-ID TO BILL-PLAN-ID
           MOVE WS-BASE-AMT TO BILL-BASE-AMT
           MOVE WS-DISC-PCT TO BILL-DISC-PCT
           MOVE WS-DISC-AMT TO BILL-DISC-AMT
           MOVE WS-TAX-AMT TO BILL-TAX-AMT
           MOVE WS-FINAL-AMT TO BILL-FINAL-AMT
           MOVE VAL-BILL-DATE TO BILL-DATE

           WRITE BILL-RECORD
           ADD 1 TO WS-BILLS-GEN-COUNT

           ADD WS-BASE-AMT TO WS-TOTAL-BASE-AMT
           ADD WS-DISC-AMT TO WS-TOTAL-DISC-AMT
           ADD WS-TAX-AMT TO WS-TOTAL-TAX-AMT
           ADD WS-FINAL-AMT TO WS-TOTAL-FINAL-AMT.

       4000-TERMINATE.
           CLOSE VALID-FILE
           CLOSE BILL-FILE

           DISPLAY "--------------------------------------------------"
           DISPLAY "BILLPROC EXECUTION SUMMARY:"
           DISPLAY "  RECORDS READ FROM VALIDSUB:  " WS-VALID-IN-COUNT
           DISPLAY "  BILLS GENERATED:             " WS-BILLS-GEN-COUNT
           DISPLAY "  TOTAL BASE BILLED:           " WS-TOTAL-BASE-AMT
           DISPLAY "  TOTAL DISCOUNT APPLIED:      " WS-TOTAL-DISC-AMT
           DISPLAY "  TOTAL 18% TAX CHARGED:       " WS-TOTAL-TAX-AMT
           DISPLAY "  TOTAL FINAL REVENUE BILLED:  " WS-TOTAL-FINAL-AMT
           DISPLAY "--------------------------------------------------"
           DISPLAY "BILLPROC: COND CODE SET TO 0000 (NORMAL)"
           MOVE 0 TO RETURN-CODE.
