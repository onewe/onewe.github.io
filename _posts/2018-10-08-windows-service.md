---
title: 用c写windows服务程序
date: 2018/10/08 15:58:12
tags:
- windows service
categories: c
cover: https://gitee.com/oneww/onew_image/raw/master/windows_service_cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: windows服务,坑真多.此文作为踩坑记录.
---



# 一、前言

最近公司需要在windows平台上做一个服务程序,不幸的是这个任务落在我这个不怎么会c/c++的人身上了,于是拿起一本<<C语言入门到精通>>就开始干了.在编码期间发现win32 API 有不少的坑.在此记录一下.



# 二、上代码

1. 安装服务,相当于在服务控制器中注册一个服务.

   ![IoW3Qg](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/IoW3Qg.jpg)

   ```c
   //判断是否已经安装过服务
   BOOL IsInstalled() {
   	BOOL bResult = FALSE;
   	SC_HANDLE hScm = OpenSCManager(NULL, NULL, SC_MANAGER_CREATE_SERVICE);
   	if (hScm != NULL) {
   		SC_HANDLE hService = OpenService(hScm, L"XXXX", SERVICE_QUERY_CONFIG);
   		if (hService != NULL) {
   			bResult = TRUE;
   			CloseServiceHandle(hService);
   		}
   		CloseServiceHandle(hScm);
   	}
   	return bResult;
   }
   
   //安装服务
   BOOL InstallService() {
   	log_i(_T("安装服务中...\n"));
   	if (IsInstalled()) {
   		log_i(_T("服务已安装...\n"));
   		return FALSE;
   	}
   
   	//打开服务控制器
   	SC_HANDLE hScm = OpenSCManager(NULL, NULL, SC_MANAGER_CREATE_SERVICE);
   	if (hScm == NULL) {
   		log_e(_T("打开服务控制器失败...\n"));
   		return FALSE;
   	}
   	TCHAR * path = GetFullPath();
   	SC_HANDLE hService = CreateService(hScm, 
   		L"TestService", 
   		L"TestService",
   		SERVICE_QUERY_STATUS,
   		SERVICE_WIN32_OWN_PROCESS, 
   		SERVICE_AUTO_START,
   		SERVICE_ERROR_NORMAL, 
   		path,
   		NULL, 
   		NULL, 
   		NULL, 
   		NULL,
   		NULL);
   	if (hService == NULL){
   		log_e(_T("服务创建失败...\n"));
   		return FALSE;
   	}
   	//释放句柄
   	CloseServiceHandle(hScm);
   	CloseServiceHandle(hService);
   	return TRUE;
   }
   ```

   上面代码执行后,不出问题的话就可以在服务控制管理器看到自己创建的服务了.

   - 服务名称和二进制文件路径全部都要是宽字符,不能是char(窄字符)类型的,如果是char类型那么服务名称和二进制文件路径就会出现乱码的情况.使用`L"XXXX"`就表示宽字符,也可以用`_T("XXX")` 来转换为宽字符

2. 运行服务,注册好服务以后,点击启动服务,windows 会调用特定函数进行调用.

   ```c
   SERVICE_STATUS                      ServiceStatus;                              //服务状态
   SERVICE_STATUS_HANDLE               hStatus;                                    //服务状态句柄
   
   //服务入库函数
   void WINAPI ServiceMain(DWORD argc, PWSTR* argv) {
   
   	ServiceStatus.dwServiceType = SERVICE_WIN32_OWN_PROCESS | SERVICE_INTERACTIVE_PROCESS;
   	ServiceStatus.dwCurrentState = SERVICE_START_PENDING;
   	ServiceStatus.dwControlsAccepted = SERVICE_ACCEPT_SHUTDOWN | SERVICE_ACCEPT_STOP;
   	ServiceStatus.dwWin32ExitCode = NO_ERROR;
   	ServiceStatus.dwServiceSpecificExitCode = NO_ERROR;
   	ServiceStatus.dwCheckPoint = 0;
   	ServiceStatus.dwWaitHint = 0;
   
   	hStatus = RegisterServiceCtrlHandler(ServiceName, ServiceCtrlHandler);
   	if (!hStatus)
   	{
   		DWORD dwError = GetLastError();
   		log_e(_T("启动服务失败!%d\n"), dwError);
   		return;
   	}
   
   	//设置服务状态
   	ServiceStatus.dwCurrentState = SERVICE_RUNNING;
   	SetServiceStatus(hStatus, &ServiceStatus);
   	
   	Run();
   
   	//停止服务
   	ServiceStatus.dwCurrentState = SERVICE_STOP_PENDING;
   	SetServiceStatus(hStatus, &ServiceStatus);
   }
   
   //服务回调
   void WINAPI ServiceCtrlHandler(DWORD fdwControl)
   {
   	switch (fdwControl) {
   	case SERVICE_CONTROL_STOP:
   		log_i(_T("服务停止...\n"));
   		ServiceStatus.dwCurrentState = SERVICE_STOPPED;
   		ServiceStatus.dwWin32ExitCode = 0;
   		SetServiceStatus(hStatus, &ServiceStatus);
   		break;
   	case SERVICE_CONTROL_SHUTDOWN:
   		log_i(_T("服务终止...\n"));
   		ServiceStatus.dwCurrentState = SERVICE_STOPPED;
   		ServiceStatus.dwWin32ExitCode = 0;
   		SetServiceStatus(hStatus, &ServiceStatus);
   		break;
   	default:
   		break;
   	}
   }
   
   //运行真正的程序逻辑diamante
   void Run() {
       while(TRUE){
           printf("test\n");
       }
   }
   
   //运行服务
   void RunService() {
   	SERVICE_TABLE_ENTRY ServiceTable[2];
   	ServiceTable[0].lpServiceName = ServiceName;
   	ServiceTable[0].lpServiceProc = (LPSERVICE_MAIN_FUNCTION)ServiceMain;//函数指针
   	ServiceTable[1].lpServiceName = NULL;
   	ServiceTable[1].lpServiceProc = NULL;
   	StartServiceCtrlDispatcher(ServiceTable);
   }
   
   //程序主函数
   int wmain(int argc, wchar_t *argv[]) {
       //运行服务
       RunService();
   }
   
   ```

   - 在windows 调用ServiceMain 这个函数的过程中,一定不要费时,也就是说中间不要写耗费时间的代码,或者出现导致程序退出的错误,否则服务启动不成功.
   - 如果程序访问了C盘的文件,要注意权限的问题.否则服务启动不成功.
   - 一定要先注册服务在启动服务,如果没有注册服务就执行`RunService`这个方法,程序会报错并退出,`RunService`这个方法一定要由windows进行调用,否则失败.
   - 不能调试.

3. 看完上面的两点,是不是觉得安装服务,和启动服务的代码不能写在一个程序里面呢?其实是可以的,通过程序的启动参数设置程序不同的行为,比如不带参数启动程序视为安装服务,带参数启动程序视为启动服务.





# 三、总结

不知道国内是资料少还是我关键词不对,在写的过程中遇到了很多的问题,还好都能通过google或者百度解决.以上就是我遇到的坑的总结,可能总结的不够全面,有些地方描述的不够准确,望指正!
