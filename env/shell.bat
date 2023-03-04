@echo off

set test_vcvars="C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"

IF NOT EXIST %test_vcvars% (
    set test_vcvars="C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat"
)
call %test_vcvars%

set DIRCMD=/o

set proj_root=%~dp0
pushd "%proj_root%\.."
set proj_root=%cd%
popd

set path="%proj_root%\env";%path%

IF EXIST "%proj_root%\env\vimconfig" (
    set HOME="%proj_root%\env\vimconfig"
) ELSE IF EXIST X:\global_vim (
    set HOME=X:\global_vim
)
