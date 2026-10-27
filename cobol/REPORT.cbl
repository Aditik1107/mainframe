*> ================================================================*
*>  PROGRAM:    REPORT.CBL                                         *
*>  TITLE:      MAINFRAME BILLING & REVENUE REPORT GENERATOR       *
*>  STEP:       STEP06 OF JOB SUBBILL01                            *
*>  PURPOSE:    READS BILLS.DAT, REVENUE.DAT, AND EXCEPTION.DAT.   *
*>              GENERATES THREE STANDARDIZED MANAGEMENT REPORTS:   *
*>              1. BILLRPT.TXT  - DETAILED BILLING REGISTER        *
*>              2. REVRPT.TXT   - EXECUTIVE REVENUE SUMMARY        *
*>              3. EXCPRPT.TXT  - EXCEPTION & AUDIT REJECTION LOG  *
*> ================================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. REPORT.
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

           SELECT REV-FILE ASSIGN TO "data/REVENUE.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-REV-ST.

           SELECT EXCP-FILE ASSIGN TO "data/EXCEPTION.DAT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-EXCP-ST.

           SELECT BILL-RPT-FILE ASSIGN TO "data/BILLRPT.TXT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-BRPT-ST.

           SELECT REV-RPT-FILE ASSIGN TO "data/REVRPT.TXT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-RRPT-ST.

           SELECT EXCP-RPT-FILE ASSIGN TO "data/EXCPRPT.TXT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-ERPT-ST.

       DATA DIVISION.
       FILE SECTION.
       FD  BILL-FILE.
       COPY "copybooks/BILLREC.cpy".

       FD  REV-FILE.
       COPY "copybooks/REVREC.cpy".

       FD  EXCP-FILE.
       COPY "copybooks/EXCPREC.cpy".

       FD  BILL-RPT-FILE.
       01  BILL-RPT-LINE               PIC X(120).

       FD  REV-RPT-FILE.
       01  REV-RPT-LINE                PIC X(120).

       FD  EXCP-RPT-FILE.
       01  EXCP-RPT-LINE               PIC X(120).

       WORKING-STORAGE SECTION.
*>  File Statuses
       01  WS-FILE-STATUSES.
           05  WS-BILL-ST              PIC XX VALUE SPACES.
           05  WS-REV-ST               PIC XX VALUE SPACES.
           05  WS-EXCP-ST              PIC XX VALUE SPACES.
           05  WS-BRPT-ST              PIC XX VALUE SPACES.
           05  WS-RRPT-ST              PIC XX VALUE SPACES.
           05  WS-ERPT-ST              PIC XX VALUE SPACES.

*>  EOF Flags
       01  WS-FLAGS.
           05  WS-BILL-EOF             PIC X  VALUE 'N'.
           05  WS-REV-EOF              PIC X  VALUE 'N'.
           05  WS-EXCP-EOF             PIC X  VALUE 'N'.

*>  Date Formatting
       01  WS-CURR-DATE-DATA.
           05  WS-CURR-YEAR            PIC 9(04).
           05  WS-CURR-MONTH           PIC 9(02).
           05  WS-CURR-DAY             PIC 9(02).
           05  WS-DATE-STR             PIC X(10).

*>  Report Totals & Counters
       01  WS-TOTALS.
           05  WS-BILL-CNT             PIC 9(05) VALUE 0.
           05  WS-EXCP-CNT             PIC 9(05) VALUE 0.
           05  WS-TOT-BASE             PIC 9(09)V99 VALUE 0.
           05  WS-TOT-DISC             PIC 9(09)V99 VALUE 0.
           05  WS-TOT-TAX              PIC 9(09)V99 VALUE 0.
           05  WS-TOT-FINAL            PIC 9(09)V99 VALUE 0.

*>  Formatted Output Fields
       01  WS-FORMAT-BILL-LINE.
           05  FB-BILL-ID              PIC X(12).
           05  FILLER                  PIC X(2) VALUE "  ".
           05  FB-SUB-ID               PIC X(10).
           05  FILLER                  PIC X(2) VALUE "  ".
           05  FB-CUST-ID              PIC X(10).
           05  FILLER                  PIC X(2) VALUE "  ".
           05  FB-PLAN-ID              PIC X(08).
           05  FILLER                  PIC X(2) VALUE "  ".
           05  FB-BASE-AMT             PIC ZZ,ZZ9.99.
           05  FILLER                  PIC X(2) VALUE "  ".
           05  FB-DISC-PCT             PIC Z9.99.
           05  FILLER                  PIC X(1) VALUE "%".
           05  FILLER                  PIC X(2) VALUE "  ".
           05  FB-DISC-AMT             PIC ZZ,ZZ9.99.
           05  FILLER                  PIC X(2) VALUE "  ".
           05  FB-TAX-AMT              PIC ZZ,ZZ9.99.
           05  FILLER                  PIC X(2) VALUE "  ".
           05  FB-FINAL-AMT            PIC ZZZ,ZZ9.99.

       01  WS-FORMAT-REV-LINE.
           05  FR-PLAN-ID              PIC X(08).
           05  FILLER                  PIC X(2) VALUE "  ".
           05  FR-PLAN-NAME            PIC X(25).
           05  FILLER                  PIC X(2) VALUE "  ".
           05  FR-SUB-CNT              PIC ZZZZ9.
           05  FILLER                  PIC X(3) VALUE "   ".
           05  FR-BILLED               PIC ZZZ,ZZZ,ZZ9.99.
           05  FILLER                  PIC X(3) VALUE "   ".
           05  FR-RECEIVED             PIC ZZZ,ZZZ,ZZ9.99.
           05  FILLER                  PIC X(3) VALUE "   ".
           05  FR-OUTSTAND             PIC ZZZ,ZZZ,ZZ9.99.

       01  WS-FORMAT-EXCP-LINE.
           05  FE-STEP                 PIC X(08).
           05  FILLER                  PIC X(2) VALUE "  ".
           05  FE-KEY                  PIC X(12).
           05  FILLER                  PIC X(2) VALUE "  ".
           05  FE-CODE                 PIC X(06).
           05  FILLER                  PIC X(2) VALUE "  ".
           05  FE-DESC                 PIC X(45).
           05  FILLER                  PIC X(2) VALUE "  ".
           05  FE-TIME                 PIC X(19).

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-GENERATE-BILL-REPORT
           PERFORM 3000-GENERATE-REV-REPORT
           PERFORM 4000-GENERATE-EXCP-REPORT
           PERFORM 5000-TERMINATE
           STOP RUN.

       1000-INITIALIZE.
           DISPLAY "=================================================="
           DISPLAY "REPORT: STEP06 - MAINFRAME REPORT GENERATION"
           DISPLAY "=================================================="

           MOVE FUNCTION CURRENT-DATE (1:4) TO WS-CURR-YEAR
           MOVE FUNCTION CURRENT-DATE (5:2) TO WS-CURR-MONTH
           MOVE FUNCTION CURRENT-DATE (7:2) TO WS-CURR-DAY
           
           STRING WS-CURR-YEAR "-" WS-CURR-MONTH "-" WS-CURR-DAY
               DELIMITED BY SIZE INTO WS-DATE-STR

           OPEN INPUT BILL-FILE
           OPEN INPUT REV-FILE
           OPEN INPUT EXCP-FILE

           OPEN OUTPUT BILL-RPT-FILE
           OPEN OUTPUT REV-RPT-FILE
           OPEN OUTPUT EXCP-RPT-FILE.

       2000-GENERATE-BILL-REPORT.
           WRITE BILL-RPT-LINE FROM
               "========================================================================================================================"
           WRITE BILL-RPT-LINE FROM
               "MAINFRAME SUBSCRIPTION BILLING SYSTEM (JOB SUBBILL01)               REPORT: BILLRPT - DETAILED BILLING REGISTER"
           STRING "RUN DATE: " WS-DATE-STR "                                                       PAGE: 0001"
               DELIMITED BY SIZE INTO BILL-RPT-LINE
           WRITE BILL-RPT-LINE
           WRITE BILL-RPT-LINE FROM
               "========================================================================================================================"
           WRITE BILL-RPT-LINE FROM
               "BILL ID       SUB ID      CUST ID     PLAN      BASE AMT    DISC %    DISC AMT     TAX (18%)     FINAL BILL"
           WRITE BILL-RPT-LINE FROM
               "------------  ----------  ----------  --------  ----------  --------  ----------  ------------  -----------"

           MOVE 'N' TO WS-BILL-EOF
           PERFORM UNTIL WS-BILL-EOF = 'Y'
               READ BILL-FILE
                   AT END
                       MOVE 'Y' TO WS-BILL-EOF
                   NOT AT END
                       ADD 1 TO WS-BILL-CNT
                       ADD BILL-BASE-AMT TO WS-TOT-BASE
                       ADD BILL-DISC-AMT TO WS-TOT-DISC
                       ADD BILL-TAX-AMT TO WS-TOT-TAX
                       ADD BILL-FINAL-AMT TO WS-TOT-FINAL

                       MOVE BILL-ID TO FB-BILL-ID
                       MOVE BILL-SUB-ID TO FB-SUB-ID
                       MOVE BILL-CUST-ID TO FB-CUST-ID
                       MOVE BILL-PLAN-ID TO FB-PLAN-ID
                       MOVE BILL-BASE-AMT TO FB-BASE-AMT
                       MOVE BILL-DISC-PCT TO FB-DISC-PCT
                       MOVE BILL-DISC-AMT TO FB-DISC-AMT
                       MOVE BILL-TAX-AMT TO FB-TAX-AMT
                       MOVE BILL-FINAL-AMT TO FB-FINAL-AMT

                       WRITE BILL-RPT-LINE FROM WS-FORMAT-BILL-LINE
               END-READ
           END-PERFORM

           WRITE BILL-RPT-LINE FROM
               "------------------------------------------------------------------------------------------------------------------------"
           MOVE SPACES TO BILL-RPT-LINE
           STRING "TOTAL BILLS: " WS-BILL-CNT
                  "          GRAND TOTAL BILLED: " WS-TOT-FINAL
               DELIMITED BY SIZE INTO BILL-RPT-LINE
           WRITE BILL-RPT-LINE
           WRITE BILL-RPT-LINE FROM
               "========================================================================================================================"
           CLOSE BILL-FILE
           CLOSE BILL-RPT-FILE
           DISPLAY "REPORT: BILLRPT.TXT SUCCESSFULLY GENERATED".

       3000-GENERATE-REV-REPORT.
           WRITE REV-RPT-LINE FROM
               "========================================================================================================================"
           WRITE REV-RPT-LINE FROM
               "MAINFRAME REVENUE MANAGEMENT SYSTEM (JOB SUBBILL01)                 REPORT: REVRPT - EXECUTIVE REVENUE SUMMARY"
           STRING "RUN DATE: " WS-DATE-STR "                                                       PAGE: 0001"
               DELIMITED BY SIZE INTO REV-RPT-LINE
           WRITE REV-RPT-LINE
           WRITE REV-RPT-LINE FROM
               "========================================================================================================================"
           WRITE REV-RPT-LINE FROM
               "PLAN ID   PLAN NAME                  SUBS      BILLED REVENUE        RECEIVED PAYMENTS     OUTSTANDING AMOUNT"
           WRITE REV-RPT-LINE FROM
               "--------  -------------------------  -----  --------------------  --------------------  --------------------"

           MOVE 'N' TO WS-REV-EOF
           PERFORM UNTIL WS-REV-EOF = 'Y'
               READ REV-FILE
                   AT END
                       MOVE 'Y' TO WS-REV-EOF
                   NOT AT END
                       MOVE REV-PLAN-ID TO FR-PLAN-ID
                       MOVE REV-PLAN-NAME TO FR-PLAN-NAME
                       MOVE REV-SUB-COUNT TO FR-SUB-CNT
                       MOVE REV-BILLED-AMT TO FR-BILLED
                       MOVE REV-RECEIVED-AMT TO FR-RECEIVED
                       MOVE REV-OUTSTAND-AMT TO FR-OUTSTAND
                       WRITE REV-RPT-LINE FROM WS-FORMAT-REV-LINE
               END-READ
           END-PERFORM

           WRITE REV-RPT-LINE FROM
               "========================================================================================================================"
           CLOSE REV-FILE
           CLOSE REV-RPT-FILE
           DISPLAY "REPORT: REVRPT.TXT SUCCESSFULLY GENERATED".

       4000-GENERATE-EXCP-REPORT.
           WRITE EXCP-RPT-LINE FROM
               "========================================================================================================================"
           WRITE EXCP-RPT-LINE FROM
               "MAINFRAME EXCEPTION AUDIT SYSTEM (JOB SUBBILL01)                    REPORT: EXCPRPT - BATCH EXCEPTION & REJECTION LOG"
           STRING "RUN DATE: " WS-DATE-STR "                                                       PAGE: 0001"
               DELIMITED BY SIZE INTO EXCP-RPT-LINE
           WRITE EXCP-RPT-LINE
           WRITE EXCP-RPT-LINE FROM
               "========================================================================================================================"
           WRITE EXCP-RPT-LINE FROM
               "STEP      RECORD KEY    CODE    FAILURE REASON / EXCEPTION DESCRIPTION       TIMESTAMP"
           WRITE EXCP-RPT-LINE FROM
               "--------  ------------  ------  -------------------------------------------  -------------------"

           MOVE 'N' TO WS-EXCP-EOF
           PERFORM UNTIL WS-EXCP-EOF = 'Y'
               READ EXCP-FILE
                   AT END
                       MOVE 'Y' TO WS-EXCP-EOF
                   NOT AT END
                       ADD 1 TO WS-EXCP-CNT
                       MOVE EXCP-SOURCE-STEP TO FE-STEP
                       MOVE EXCP-RECORD-KEY TO FE-KEY
                       MOVE EXCP-ERR-CODE TO FE-CODE
                       MOVE EXCP-ERR-DESC TO FE-DESC
                       MOVE EXCP-TIMESTAMP TO FE-TIME
                       WRITE EXCP-RPT-LINE FROM WS-FORMAT-EXCP-LINE
               END-READ
           END-PERFORM

           WRITE EXCP-RPT-LINE FROM
               "------------------------------------------------------------------------------------------------------------------------"
           MOVE SPACES TO EXCP-RPT-LINE
           STRING "TOTAL EXCEPTION RECORDS DIVERTED: " WS-EXCP-CNT
                  " (BATCH PROCEEDED WITHOUT INTERRUPTION)"
               DELIMITED BY SIZE INTO EXCP-RPT-LINE
           WRITE EXCP-RPT-LINE
           WRITE EXCP-RPT-LINE FROM
               "========================================================================================================================"
           CLOSE EXCP-FILE
           CLOSE EXCP-RPT-FILE
           DISPLAY "REPORT: EXCPRPT.TXT SUCCESSFULLY GENERATED".

       5000-TERMINATE.
           DISPLAY "--------------------------------------------------"
           DISPLAY "REPORT EXECUTION COMPLETED SUCCESSFULLY"
           DISPLAY "  REPORTS DELIVERED TO SPOOL / DATASET REPOSITORY"
           DISPLAY "--------------------------------------------------"
           DISPLAY "REPORT: COND CODE SET TO 0000 (NORMAL)"
           MOVE 0 TO RETURN-CODE.
