//SUBBILL01 JOB (MAINFRAME,PROD),'SUBSCRIPTION BILL',
//             CLASS=A,
//             MSGCLASS=X,
//             MSGLEVEL=(1,1),
//             NOTIFY=&SYSUID
//*===================================================================*
//* JOB NAME:  SUBBILL01                                              *
//* TITLE:     MAINFRAME AUTOMATED BATCH SUBSCRIPTION BILLING,        *
//*            PAYMENT VALIDATION AND REVENUE REPORTING SYSTEM        *
//* INVENTORS: PROF. MADHURA SANAP, ADITI KADAM,                      *
//*            SHARAYU ITKIKAR, SMRUTI GADAVE                         *
//* APPLICANT: VISHWAKARMA INSTITUTE OF TECHNOLOGY & VU PUNE          *
//*===================================================================*
//*
//*-------------------------------------------------------------------*
//* STEP01: IDCAMS UTILITY - ALLOCATE AND INITIALIZE VSAM DATASETS    *
//*-------------------------------------------------------------------*
//STEP01   EXEC PGM=IDCAMS
//SYSPRINT DD  SYSOUT=*
//SYSIN    DD  *
  /* DELETE EXISTING OUTPUT / WORKING DATASETS */
  DELETE PROD.SUBSYS.VALIDSUB.CLUSTER PURGE
  DELETE PROD.SUBSYS.BILLS.CLUSTER PURGE
  DELETE PROD.SUBSYS.PAYOUT.CLUSTER PURGE
  DELETE PROD.SUBSYS.REVENUE.CLUSTER PURGE
  SET MAXCC = 0
/*
//*
//*-------------------------------------------------------------------*
//* STEP02: SUBVAL - VALIDATE CUSTOMER, SUBSCRIPTION AND PLAN MASTER  *
//* DIVERTS INVALID / INACTIVE RECORDS TO EXCEPTION DATASET           *
//*-------------------------------------------------------------------*
//STEP02   EXEC PGM=SUBVAL
//STEPLIB  DD  DSN=PROD.SUBSYS.LOADLIB,DISP=SHR
//CUSTMST  DD  DSN=PROD.SUBSYS.CUSTMAST.KSDS,DISP=SHR
//SUBMST   DD  DSN=PROD.SUBSYS.SUBMAST.KSDS,DISP=SHR
//PLANMST  DD  DSN=PROD.SUBSYS.PLANMAST.KSDS,DISP=SHR
//VALDSUB  DD  DSN=PROD.SUBSYS.VALIDSUB.DATA,
//             DISP=(NEW,CATLG,DELETE),
//             SPACE=(CYL,(10,5),RLSE),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//EXCPOUT  DD  DSN=PROD.SUBSYS.EXCEPTION.DATA,
//             DISP=(MOD,CATLG,CATLG),
//             SPACE=(CYL,(5,5),RLSE),
//             DCB=(RECFM=FB,LRECL=100,BLKSIZE=1000)
//SYSOUT   DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//*
//*-------------------------------------------------------------------*
//* STEP03: BILLPROC - CALCULATE DURATION-BASED DISCOUNT AND 18% TAX  *
//* CONDITION: RUN ONLY IF STEP02 RETURN CODE <= 4                    *
//*-------------------------------------------------------------------*
//STEP03   EXEC PGM=BILLPROC,COND=(4,LT,STEP02)
//STEPLIB  DD  DSN=PROD.SUBSYS.LOADLIB,DISP=SHR
//VALDSUB  DD  DSN=PROD.SUBSYS.VALIDSUB.DATA,DISP=SHR
//PLANMST  DD  DSN=PROD.SUBSYS.PLANMAST.KSDS,DISP=SHR
//BILLOUT  DD  DSN=PROD.SUBSYS.BILLS.DATA,
//             DISP=(NEW,CATLG,DELETE),
//             SPACE=(CYL,(10,5),RLSE),
//             DCB=(RECFM=FB,LRECL=100,BLKSIZE=1000)
//SYSOUT   DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//*
//*-------------------------------------------------------------------*
//* STEP04: PAYPROC - PAYMENT MATCHING AND RECONCILIATION             *
//* CLASSIFIES: SUCCESS, AMOUNT MISMATCH, FAILED, DUPLICATE           *
//* CONDITION: RUN ONLY IF STEP03 RETURN CODE <= 4                    *
//*-------------------------------------------------------------------*
//STEP04   EXEC PGM=PAYPROC,COND=(4,LT,STEP03)
//STEPLIB  DD  DSN=PROD.SUBSYS.LOADLIB,DISP=SHR
//BILLIN   DD  DSN=PROD.SUBSYS.BILLS.DATA,DISP=SHR
//PAYIN    DD  DSN=PROD.SUBSYS.PAYMENT.DATA,DISP=SHR
//PAYOUT   DD  DSN=PROD.SUBSYS.PAYOUT.DATA,
//             DISP=(NEW,CATLG,DELETE),
//             SPACE=(CYL,(10,5),RLSE),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//EXCPOUT  DD  DSN=PROD.SUBSYS.EXCEPTION.DATA,
//             DISP=(MOD,CATLG,CATLG)
//SYSOUT   DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//*
//*-------------------------------------------------------------------*
//* STEP05: REVPROC - AGGREGATE BILLED, RECEIVED AND OUTSTANDING REV *
//* CONDITION: RUN ONLY IF STEP04 RETURN CODE <= 4                    *
//*-------------------------------------------------------------------*
//STEP05   EXEC PGM=REVPROC,COND=(4,LT,STEP04)
//STEPLIB  DD  DSN=PROD.SUBSYS.LOADLIB,DISP=SHR
//PLANMST  DD  DSN=PROD.SUBSYS.PLANMAST.KSDS,DISP=SHR
//BILLIN   DD  DSN=PROD.SUBSYS.BILLS.DATA,DISP=SHR
//PAYIN    DD  DSN=PROD.SUBSYS.PAYOUT.DATA,DISP=SHR
//REVOUT   DD  DSN=PROD.SUBSYS.REVENUE.DATA,
//             DISP=(NEW,CATLG,DELETE),
//             SPACE=(CYL,(5,2),RLSE),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//SYSOUT   DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//*
//*-------------------------------------------------------------------*
//* STEP06: REPORT - FORMAT AND GENERATE OFFICIAL PRINT REPORTS       *
//* BILLRPT (REGISTER), REVRPT (SUMMARY), EXCPRPT (AUDIT LOG)        *
//* CONDITION: RUN ONLY IF STEP05 RETURN CODE <= 4                    *
//*-------------------------------------------------------------------*
//STEP06   EXEC PGM=REPORT,COND=(4,LT,STEP05)
//STEPLIB  DD  DSN=PROD.SUBSYS.LOADLIB,DISP=SHR
//BILLIN   DD  DSN=PROD.SUBSYS.BILLS.DATA,DISP=SHR
//REVIN    DD  DSN=PROD.SUBSYS.REVENUE.DATA,DISP=SHR
//EXCPIN   DD  DSN=PROD.SUBSYS.EXCEPTION.DATA,DISP=SHR
//BILLRPT  DD  DSN=PROD.SUBSYS.BILLRPT.PRINT,
//             DISP=(NEW,CATLG,DELETE),
//             DCB=(RECFM=FBA,LRECL=120,BLKSIZE=1200)
//REVRPT   DD  DSN=PROD.SUBSYS.REVRPT.PRINT,
//             DISP=(NEW,CATLG,DELETE),
//             DCB=(RECFM=FBA,LRECL=120,BLKSIZE=1200)
//EXCPRPT  DD  DSN=PROD.SUBSYS.EXCPRPT.PRINT,
//             DISP=(NEW,CATLG,DELETE),
//             DCB=(RECFM=FBA,LRECL=120,BLKSIZE=1200)
//SYSOUT   DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//*
//*-------------------------------------------------------------------*
//* STEP07: BACKUP - ARCHIVE BATCH ARTIFACTS AND DISPATCH SPOOL       *
//*-------------------------------------------------------------------*
//STEP07   EXEC PGM=IEBGENER,COND=(4,LT,STEP06)
//SYSUT1   DD  DSN=PROD.SUBSYS.EXCEPTION.DATA,DISP=SHR
//SYSUT2   DD  DSN=PROD.SUBSYS.ARCHIVE.EXCP(+1),
//             DISP=(NEW,CATLG,DELETE),
//             UNIT=TAPE,
//             DCB=(RECFM=FB,LRECL=100,BLKSIZE=1000)
//SYSPRINT DD  SYSOUT=*
//SYSIN    DD  DUMMY
//
