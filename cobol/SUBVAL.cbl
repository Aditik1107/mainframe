*> ================================================================
*> PROGRAM:    SUBVAL.CBL                                         *
*> TITLE:      SUBSCRIPTION RECORD VALIDATION PROGRAM             *
*> STEP:       STEP02 OF JOB SUBBILL01                            *
*> PURPOSE:    VALIDATES CUSTOMER, SUBSCRIPTION, PLAN AND DATE.   *
*>             WRITES VALID RECORDS TO VALIDSUB.DAT.              *
*>             DIVERTS DEFECTIVE RECORDS TO EXCEPTION.DAT.        *
*> ================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SUBVAL.
       AUTHOR. VIT-VU-TEAM.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-Z.
       OBJECT-COMPUTER. IBM-Z.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CUST-FILE ASSIGN TO "data/CUSTMAST.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-CUST-ST.

           SELECT SUB-FILE ASSIGN TO "data/SUBMAST.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-SUB-ST.

           SELECT PLAN-FILE ASSIGN TO "data/PLANMAST.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-PLAN-ST.

           SELECT VALID-FILE ASSIGN TO "data/VALIDSUB.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-VAL-ST.

           SELECT EXCP-FILE ASSIGN TO "data/EXCEPTION.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-EXCP-ST.

       DATA DIVISION.
       FILE SECTION.
       FD  CUST-FILE.
       COPY "copybooks/CUSTREC.cpy".

       FD  SUB-FILE.
       COPY "copybooks/SUBREC.cpy".

       FD  PLAN-FILE.
       COPY "copybooks/PLANREC.cpy".

       FD  VALID-FILE.
       COPY "copybooks/VALIDSUB.cpy".

       FD  EXCP-FILE.
       COPY "copybooks/EXCPREC.cpy".

       WORKING-STORAGE SECTION.
*> File Status variables
       01  WS-FILE-STATUSES.
           05  WS-CUST-ST              PIC XX VALUE SPACES.
           05  WS-SUB-ST               PIC XX VALUE SPACES.
           05  WS-PLAN-ST              PIC XX VALUE SPACES.
           05  WS-VAL-ST               PIC XX VALUE SPACES.
           05  WS-EXCP-ST              PIC XX VALUE SPACES.

*> EOF Flags
       01  WS-FLAGS.
           05  WS-SUB-EOF              PIC X  VALUE 'N'.
           05  WS-CUST-EOF             PIC X  VALUE 'N'.
           05  WS-PLAN-EOF             PIC X  VALUE 'N'.
           05  WS-RECORD-VALID         PIC X  VALUE 'Y'.

*> Exception Parameters
       01  WS-EXCP-PARMS.
           05  WS-EP-CODE              PIC X(06).
           05  WS-EP-DESC              PIC X(45).

*> Counters
       01  WS-COUNTERS.
           05  WS-SUB-COUNT            PIC 9(05) VALUE 0.
           05  WS-VALID-COUNT          PIC 9(05) VALUE 0.
           05  WS-EXCP-COUNT           PIC 9(05) VALUE 0.
           05  WS-CUST-TBL-SIZE        PIC 9(03) VALUE 0.
           05  WS-PLAN-TBL-SIZE        PIC 9(03) VALUE 0.
           05  WS-IDX                  PIC 9(03) VALUE 0.

*> Current Date / Timestamp
       01  WS-CURRENT-DATE-DATA.
           05  WS-CURR-YEAR            PIC 9(04).
           05  WS-CURR-MONTH           PIC 9(02).
           05  WS-CURR-DAY             PIC 9(02).
           05  WS-CURR-HOUR            PIC 9(02).
           05  WS-CURR-MIN             PIC 9(02).
           05  WS-CURR-SEC             PIC 9(02).
           05  WS-TIMESTAMP-STR        PIC X(19).
           05  WS-TODAY-DATE           PIC X(10).

*> In-Memory Master Tables for Fast Key Lookups
       01  WS-CUST-TABLE.
           05  WS-CUST-ENTRY OCCURS 100 TIMES INDEXED BY CUST-IDX.
               10  TB-CUST-ID          PIC X(10).
               10  TB-CUST-NAME        PIC X(30).
               10  TB-CUST-STATUS      PIC X(01).

       01  WS-PLAN-TABLE.
           05  WS-PLAN-ENTRY OCCURS 50 TIMES INDEXED BY PLAN-IDX.
               10  TB-PLAN-ID          PIC X(08).
               10  TB-PLAN-NAME        PIC X(25).
               10  TB-PLAN-STATUS      PIC X(01).

*> Matching Work Variables
       01  WS-MATCH-VARS.
           05  WS-FOUND-CUST           PIC X VALUE 'N'.
           05  WS-FOUND-PLAN           PIC X VALUE 'N'.
           05  WS-MATCHED-NAME         PIC X(30).

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-MASTERS
           PERFORM 3000-PROCESS-SUBSCRIPTIONS
           PERFORM 4000-TERMINATE
           STOP RUN.

       1000-INITIALIZE.
           DISPLAY "=================================================="
           DISPLAY "SUBVAL: STEP02 - SUBSCRIPTION VALIDATION STARTED"
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
                  
           STRING WS-CURR-YEAR "-" WS-CURR-MONTH "-" WS-CURR-DAY
                  DELIMITED BY SIZE INTO WS-TODAY-DATE

           OPEN INPUT CUST-FILE
           IF WS-CUST-ST NOT = "00"
               DISPLAY "SUBVAL ERROR: UNABLE TO OPEN CUSTMAST ST=" WS-CUST-ST
               MOVE 8 TO RETURN-CODE
               STOP RUN
           END-IF

           OPEN INPUT PLAN-FILE
           IF WS-PLAN-ST NOT = "00"
               DISPLAY "SUBVAL ERROR: UNABLE TO OPEN PLANMAST ST=" WS-PLAN-ST
               MOVE 8 TO RETURN-CODE
               STOP RUN
           END-IF

           OPEN INPUT SUB-FILE
           IF WS-SUB-ST NOT = "00"
               DISPLAY "SUBVAL ERROR: UNABLE TO OPEN SUBMAST ST=" WS-SUB-ST
               MOVE 8 TO RETURN-CODE
               STOP RUN
           END-IF

           OPEN OUTPUT VALID-FILE
           IF WS-VAL-ST NOT = "00"
               DISPLAY "SUBVAL ERROR: UNABLE TO OPEN VALIDSUB ST=" WS-VAL-ST
               MOVE 8 TO RETURN-CODE
               STOP RUN
           END-IF

*> Open Exception file in APPEND/OUTPUT mode
           OPEN EXTEND EXCP-FILE
           IF WS-EXCP-ST NOT = "00"
               OPEN OUTPUT EXCP-FILE
           END-IF.

       2000-LOAD-MASTERS.
*> Load Customer Master into In-Memory lookup table
           MOVE 'N' TO WS-CUST-EOF
           MOVE 0 TO WS-CUST-TBL-SIZE
           PERFORM UNTIL WS-CUST-EOF = 'Y'
               READ CUST-FILE
                   AT END
                       MOVE 'Y' TO WS-CUST-EOF
                   NOT AT END
                       ADD 1 TO WS-CUST-TBL-SIZE
                       MOVE CUST-ID TO TB-CUST-ID (WS-CUST-TBL-SIZE)
                       MOVE CUST-NAME TO TB-CUST-NAME (WS-CUST-TBL-SIZE)
                       MOVE CUST-STATUS TO TB-CUST-STATUS (WS-CUST-TBL-SIZE)
               END-READ
           END-PERFORM
           CLOSE CUST-FILE
           DISPLAY "SUBVAL: LOADED " WS-CUST-TBL-SIZE " CUSTOMER RECORDS"

*> Load Plan Master into In-Memory lookup table
           MOVE 'N' TO WS-PLAN-EOF
           MOVE 0 TO WS-PLAN-TBL-SIZE
           PERFORM UNTIL WS-PLAN-EOF = 'Y'
               READ PLAN-FILE
                   AT END
                       MOVE 'Y' TO WS-PLAN-EOF
                   NOT AT END
                       ADD 1 TO WS-PLAN-TBL-SIZE
                       MOVE PLAN-ID TO TB-PLAN-ID (WS-PLAN-TBL-SIZE)
                       MOVE PLAN-NAME TO TB-PLAN-NAME (WS-PLAN-TBL-SIZE)
                       MOVE PLAN-STATUS TO TB-PLAN-STATUS (WS-PLAN-TBL-SIZE)
               END-READ
           END-PERFORM
           CLOSE PLAN-FILE
           DISPLAY "SUBVAL: LOADED " WS-PLAN-TBL-SIZE " PLAN RECORDS".

       3000-PROCESS-SUBSCRIPTIONS.
           MOVE 'N' TO WS-SUB-EOF
           PERFORM UNTIL WS-SUB-EOF = 'Y'
               READ SUB-FILE
                   AT END
                       MOVE 'Y' TO WS-SUB-EOF
                   NOT AT END
                       ADD 1 TO WS-SUB-COUNT
                       PERFORM 3100-VALIDATE-RECORD
               END-READ
           END-PERFORM.

       3100-VALIDATE-RECORD.
           MOVE 'Y' TO WS-RECORD-VALID
           MOVE 'N' TO WS-FOUND-CUST
           MOVE 'N' TO WS-FOUND-PLAN
           MOVE SPACES TO WS-MATCHED-NAME

*> Rule 301: Verify Customer exists and is active
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-CUST-TBL-SIZE OR WS-FOUND-CUST = 'Y'
               IF TB-CUST-ID (WS-IDX) = SUB-CUST-ID
                   MOVE 'Y' TO WS-FOUND-CUST
                   MOVE TB-CUST-NAME (WS-IDX) TO WS-MATCHED-NAME
                   IF TB-CUST-STATUS (WS-IDX) NOT = 'A'
                       MOVE 'N' TO WS-RECORD-VALID
                       MOVE "ERR001" TO WS-EP-CODE
                       MOVE "CUSTOMER IS INACTIVE OR SUSPENDED" TO WS-EP-DESC
                       PERFORM 3200-WRITE-EXCEPTION
                   END-IF
               END-IF
           END-PERFORM

           IF WS-FOUND-CUST = 'N' AND WS-RECORD-VALID = 'Y'
               MOVE 'N' TO WS-RECORD-VALID
               MOVE "ERR002" TO WS-EP-CODE
               MOVE "CUSTOMER ID NOT FOUND IN MASTER" TO WS-EP-DESC
               PERFORM 3200-WRITE-EXCEPTION
           END-IF

*> Rule 302: Verify Subscription is active
           IF WS-RECORD-VALID = 'Y' AND SUB-STATUS NOT = 'A'
               MOVE 'N' TO WS-RECORD-VALID
               MOVE "ERR003" TO WS-EP-CODE
               MOVE "SUBSCRIPTION STATUS IS NOT ACTIVE" TO WS-EP-DESC
               PERFORM 3200-WRITE-EXCEPTION
           END-IF

*> Rule 303: Verify Plan exists and is active
           IF WS-RECORD-VALID = 'Y'
               PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-PLAN-TBL-SIZE OR WS-FOUND-PLAN = 'Y'
                   IF TB-PLAN-ID (WS-IDX) = SUB-PLAN-ID
                       MOVE 'Y' TO WS-FOUND-PLAN
                       IF TB-PLAN-STATUS (WS-IDX) NOT = 'A'
                           MOVE 'N' TO WS-RECORD-VALID
                           MOVE "ERR004" TO WS-EP-CODE
                           MOVE "PLAN IS RETIRED OR INACTIVE" TO WS-EP-DESC
                           PERFORM 3200-WRITE-EXCEPTION
                       END-IF
                   END-IF
               END-PERFORM
               IF WS-FOUND-PLAN = 'N' AND WS-RECORD-VALID = 'Y'
                   MOVE 'N' TO WS-RECORD-VALID
                   MOVE "ERR005" TO WS-EP-CODE
                   MOVE "PLAN ID NOT FOUND IN PLAN MASTER" TO WS-EP-DESC
                   PERFORM 3200-WRITE-EXCEPTION
               END-IF
           END-IF

*> Rule 304: Verify Billing Date is valid and due
           IF WS-RECORD-VALID = 'Y'
               IF SUB-NEXT-BILL-DATE = SPACES OR
                  SUB-NEXT-BILL-DATE(1:4) < "2020"
                   MOVE 'N' TO WS-RECORD-VALID
                   MOVE "ERR006" TO WS-EP-CODE
                   MOVE "INVALID NEXT BILLING DATE FORMAT" TO WS-EP-DESC
                   PERFORM 3200-WRITE-EXCEPTION
               END-IF
           END-IF

*> If All Checks Passed -> Write to VALID-FILE
           IF WS-RECORD-VALID = 'Y'
               MOVE SPACES TO VALID-SUB-RECORD
               MOVE SUB-ID TO VAL-SUB-ID
               MOVE SUB-CUST-ID TO VAL-CUST-ID
               MOVE WS-MATCHED-NAME TO VAL-CUST-NAME
               MOVE SUB-PLAN-ID TO VAL-PLAN-ID
               MOVE SUB-DURATION-MONTHS TO VAL-DURATION-MONTHS
               MOVE SUB-NEXT-BILL-DATE TO VAL-BILL-DATE
               WRITE VALID-SUB-RECORD
               ADD 1 TO WS-VALID-COUNT
           END-IF.

       3200-WRITE-EXCEPTION.
           MOVE SPACES TO EXCEPTION-RECORD
           MOVE "SUBVAL  " TO EXCP-SOURCE-STEP
           MOVE SUB-ID TO EXCP-RECORD-KEY
           MOVE WS-EP-CODE TO EXCP-ERR-CODE
           MOVE WS-EP-DESC TO EXCP-ERR-DESC
           MOVE WS-TIMESTAMP-STR TO EXCP-TIMESTAMP
           WRITE EXCEPTION-RECORD
           ADD 1 TO WS-EXCP-COUNT.

       4000-TERMINATE.
           CLOSE SUB-FILE
           CLOSE VALID-FILE
           CLOSE EXCP-FILE
           
           DISPLAY "--------------------------------------------------"
           DISPLAY "SUBVAL EXECUTION SUMMARY:"
           DISPLAY "  TOTAL SUBSCRIPTIONS READ:    " WS-SUB-COUNT
           DISPLAY "  VALIDATED FOR BILLING:       " WS-VALID-COUNT
           DISPLAY "  DIVERTED TO EXCEPTION:       " WS-EXCP-COUNT
           DISPLAY "--------------------------------------------------"

           IF WS-EXCP-COUNT > 0
               DISPLAY "SUBVAL: COND CODE SET TO 0004 (WARNING/EXCEPTIONS)"
               MOVE 4 TO RETURN-CODE
           ELSE
               DISPLAY "SUBVAL: COND CODE SET TO 0000 (NORMAL)"
               MOVE 0 TO RETURN-CODE
           END-IF.
