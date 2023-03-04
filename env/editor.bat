@echo off

if NOT DEFINED proj_root ( call "%~dp0\shell.bat")
pushd "%proj_root%"

start gvim

popd REM %proj_root
