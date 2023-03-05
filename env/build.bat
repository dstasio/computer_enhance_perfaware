@echo off

if NOT DEFINED proj_root (
call "%~dp0\shell.bat"
)
pushd "%proj_root%"

SETLOCAL

set   code_root=%proj_root%\part1
set  common_dir=%proj_root%\common

set      ignored_warnings=-wd4201 -wd4100 -wd4189 -wd4456 -wd4505
set common_compiler_flags=-diagnostics:column -MTd -nologo -Gm- -GR- -EHa- -Od -Oi -WX -W4 %ignored_warnings% -FAsc -Z7 -I%common_dir% -DSIM86_DEBUG=1
set   common_linker_flags=-incremental:no -opt:ref


pushd %code_root%

IF NOT EXIST ".\build" ( mkdir ".\build")
pushd ".\build"

del *.pdb > NUL 2> NUL
set source_list="%code_root%\sim8086.cpp"
cl %common_compiler_flags% %source_list% /link %common_linker_flags%

popd REM .\build
popd REM .\part1

popd REM %proj_root
ENDLOCAL
