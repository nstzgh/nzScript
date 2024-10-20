@echo off
setlocal enabledelayedexpansion

rem  检查是否以管理员权限运行
net session >nul 2>&1
if errorlevel 1 (
    msg %USERNAME% "请以管理员身份运行！"
    exit /b
)

:menu
cls
echo \\nz20241019
echo ==========================================================================================
echo 请根据序号选择需要安装的功能：
echo ------------------------------------------------------------------------------------------
echo 1. 阻止3dsmax连接网络
echo 2. 阻止Maya连接网络
echo 3. 解除防火墙阻止
echo ==========================================================================================
echo.

set /p choice="请输需要执行的功能序号："

if "%choice%"=="1" (
    cls
    call :function_EnableFirewall
    call :function_SetProcess 
    call :function_FirewallRules
    echo 按任意键返回主菜单
    pause
    goto :menu

) else if "%choice%"=="2" (
    cls
    call :function_EnableFirewall
    call :function_SetProcess 
    call :function_FirewallRules
    echo 按任意键返回主菜单
    pause
    goto :menu
    
) else if "%choice%"=="3" (
    cls
    call :function_EnableFirewall
    call :function_Uninstall
    echo 按任意键返回主菜单
    pause
    goto :menu

) else (
    cls
    echo 无效选择，请重新输入
    echo 按任意键返回首页面
    pause
    goto :menu
)

rem 检测防火墙是否可以开启
:function_EnableFirewall
echo 检查防火墙是否可以开启...
echo Start-------------------------------------------------------------------------------------
rem  定义注册表路径和键名
set "regPath=HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\mpssvc"
set "valueName=Start"

rem 获取当前 Start 值
for /f "tokens=3" %%a in ('reg query "%regPath%" /v "%valueName%" 2^>nul') do (
    set "startValue=%%a"
)
echo 当前 Start 值为：%startValue%
rem 如果 Start 值不为 2，则修改为 2
if not "%startValue%"=="0x2" (
    echo 修改Start值为 0x2...
    reg add "%regPath%" /v "%valueName%" /t REG_DWORD /d 2 /f >nul
    if errorlevel 1 (
        echo 修改失败，请检查权限或其他问题
        pause
        exit
    ) else (
        echo 修改成功，需重新启动电脑并再次运行该脚本
        pause
        exit
    )
) else (
    echo 开启防火墙...
    netsh advfirewall set allprofiles state on >nul 2>&1
)

echo End---------------------------------------------------------------------------------------
echo.
exit /b


rem 获取相关进程文件目录
:function_SetProcess
if "%choice%" == "1" (
    set "software=3dsMax.exe"
    set "reg=HKEY_LOCAL_MACHINE\SOFTWARE\Autodesk\3dsMax"
) else (
    set "software=Maya.exe"
    set "reg=HKEY_LOCAL_MACHINE\SOFTWARE\Autodesk\Maya" 
) 

rem 获取软件安装目录
echo 开始在注册表中查找 %software:.exe=% 安装目录...
echo Start-------------------------------------------------------------------------------------
for /f "tokens=2*" %%A in ('reg query "%Reg%" /s ^| findstr /i "Installdir"') do (
    set "softwarePath=%%B"
    goto :found
)
echo 未找到 %software:.exe=% 安装目录
echo.
echo 按任意键返回主菜单
pause
goto :menu

:found
echo 获取到 %software:.exe=% 安装目录：%softwarePath%
rem 使用 for 命令获取路径的父目录
for %%i in ("%softwarePath%\..\..\..") do set "rootPath=%%~fi"
rem 如果有"\"则去除
if "%rootPath:~-1%"=="\" set "rootPath=%rootPath:~0,-1%"

rem 定义需要拦截的进程
set "processFile[0]=%softwarePath%%software%"
set "processFile[1]=%rootPath%\Program Files\Autodesk\Autodesk AdSSO\AdSSO.exe"
set "processFile[2]=%rootPath%\Program Files\Autodesk\AdODIS\V1\Setup\AdskAccessServiceHost.exe"
set "processFile[3]=%rootPath%\Program Files\Autodesk\AdODIS\V1\Setup\AdskAccessService.exe"
set "processFile[4]=%rootPath%\Program Files\Autodesk\AdskIdentityManager\Current\AdskIdentityManager.exe"
set "processFile[5]=%rootPath%\Program Files\Common Files\Autodesk\AdpDesktopSDK\bin\ADPClientService.exe"
set "processFile[6]=%rootPath%\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\Current\AdskLicensingAgent\AdskLicensingAgent.exe"
set "processFile[7]=%rootPath%\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\Current\AdskLicensingAnalyticsClient\AdskLicensingAnalyticsClient.exe"
set "processFile[8]=%rootPath%\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\Current\AdskLicensingService\AdskLicensingService.exe"
set "processFile[9]=%rootPath%\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\Current\AdskLicensingUpdateSupport\AdskLicensingUpdateSupport.exe"

echo End---------------------------------------------------------------------------------------
echo.
exit /b


rem 创建防火墙出入站规则，阻止软件进程连接网络
:function_FirewallRules
echo 开始向防火墙中添加出入站规则以阻止应用连接网络...
echo Start-------------------------------------------------------------------------------------
rem 添加每个存在的进程到防火墙规则
set "count=0"
for /L %%i in (0,1,9) do (
    rem 检测进程文件是否存在
    if exist "!processFile[%%i]!" (
        set /a count+=1
        rem 提取文件名和扩展名
        for %%j in ("!processFile[%%i]!") do set "ruleName=Autodesk_%%~nxj"
        rem 用错误逻辑检测规则是否已经存在
        netsh advfirewall firewall show rule name="!ruleName!" >nul 2>&1
        if errorlevel 1 (
            echo 添加的进程文件索引号：%%i
            netsh advfirewall firewall add rule name="!ruleName!" dir=out action=block program="!processFile[%%i]!" enable=yes >nul 2>&1 && echo !ruleName! （OUT）添加成功 || echo !ruleName! （OUT）添加失败
            netsh advfirewall firewall add rule name="!ruleName!" dir=in action=block program="!processFile[%%i]!" enable=yes >nul 2>&1 && echo !ruleName! （IN）添加成功 || echo !ruleName! （IN）添加失败
        ) else (
            echo 规则 !ruleName! 已存在，跳过添加。
        )
    )
)
echo.
echo 添加的条目数量: !count!
echo.
if %errorlevel% equ 0 (
    echo 成功添加防火墙出入站规则
) else (
    echo 添加防火墙出入站规则失败
)

echo End---------------------------------------------------------------------------------------
echo.
exit /b


rem 删除防火墙出入站规则
:function_Uninstall
echo 开始删除防火墙出入站规则...
echo Start-------------------------------------------------------------------------------------
rem 导出包含 "Autodesk_" 的防火墙规则到 output.txt
netsh advfirewall firewall show rule name=all | findstr /i "Autodesk_" > output.txt
rem 检查 output.txt 文件是否为空
set "ruleCount=0"
for /f "tokens=*" %%i in (output.txt) do (
    set /a ruleCount+=1
)
if %ruleCount%==0 (
    echo 没有找到任何包含 "Autodesk_" 的规则
    exit /b
)
rem 逐行读取 output.txt 中的规则并删除
echo 找到 %ruleCount% 条防火墙拦截规则，正在删除...
for /f "tokens=*" %%i in (output.txt) do (
    rem 规则名称在输出中通常位于第二列，提取名称
    for /f "tokens=2*" %%j in ("%%i") do (
    echo 删除规则 %%j
    netsh advfirewall firewall delete rule name="%%j" >nul 2>&1
    )
)

del output.txt

echo End---------------------------------------------------------------------------------------
echo.
exit /b


endlocal
pause