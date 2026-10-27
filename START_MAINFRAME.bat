@echo off
title IBM Z Mainframe Batch Subscription System
echo =======================================================================
echo   IBM Z MAINFRAME AUTOMATED SUBSCRIPTION BILLING & REPORTING SYSTEM
echo   Applicant: Vishwakarma Institute of Technology & VU Pune
echo   Inventors: Prof. Madhura Sanap, Aditi Kadam, Sharayu Itkikar, Smruti Gadave
echo =======================================================================
echo.
echo [1/3] Verifying Python and GnuCOBOL environment...
python --version
set PATH=C:\msys64\mingw64\bin;%PATH%

echo.
echo [2/3] Launching FastAPI Backend Server on http://127.0.0.1:8000...
start "" http://127.0.0.1:8000
python -m uvicorn backend.server:app --host 127.0.0.1 --port 8000 --reload
pause
