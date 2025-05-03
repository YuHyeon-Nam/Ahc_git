@echo off
chcp 949
call C:\Users\yeong\anaconda3\Scripts\activate C:\Users\yeong\anaconda3
navigator-updater --latest-version 2.6.4 --prefix C:\Users\yeong\anaconda3 >C:\SPB_Data\.anaconda\navigator\scripts\anaconda-navigator-updater-out-1.txt 2>C:\SPB_Data\.anaconda\navigator\scripts\anaconda-navigator-updater-err-1.txt
