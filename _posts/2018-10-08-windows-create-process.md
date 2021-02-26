---
title: windows用c创建进程
date: 2018/10/08 16:58:12
tags:
- windows c
- c process
categories: c
cover: https://gitee.com/oneww/onew_image/raw/master/windows_create_process_cover.jpg
author: 
  nick: onew
  link: https://onew.me
subtitle: windows 服务创建一个具有GUI的进程
---



# 一、前言

在windows服务的设计理念中,服务就是应该在后面默默无闻的跑,不要搞什么GUI之类的,但是凡事都有但是的时候,因为有些业务程序需要像服务程序一样的运行方式,也需要拥有GUI界面.然后,后面就有个session 0 隔离了,具体我也不多讲了,我也不懂.具体的百度吧哈哈哈.



# 二、上代码

1. 无GUI创建进程

   ```c
   
   PROCESS_INFORMATION					pi;											//子进程句柄
   DWORD								returnCode;									//子进程返回码
   STARTUPINFO							si = { sizeof(STARTUPINFO) };
   
   BOOL CreateProcessNoService(const wchar_t * commandLine) {
   	log_i(_T("创建进程中.....\n"));
   	return  CreateProcess(NULL, commandLine, NULL, NULL, FALSE, CREATE_NEW_CONSOLE, NULL, NULL, &si, &pi);
   }
   ```

   只要调用上面的函数就可以创建一个进程,如果不是作为服务调用创建的进程是可以创建带有GUI进程的,如果是服务调用的话就不能创建.

   - 注意:涉及到字符串的都要使用宽字符

2. 有GUI创建进程

   ```c
   PROCESS_INFORMATION					pi;											//子进程句柄
   DWORD								returnCode;									//子进程返回码
   STARTUPINFO							si = { sizeof(STARTUPINFO) };
   
   //---------------
   HANDLE								hToken;										//用户token
   HANDLE								hTokenDup;									//用户token
   LPVOID								pEnv;	
   
   
   
   //服务环境下创建进程
   BOOL CreateProcessForService(const wchar_t * commandLine) {
   	log_i(_T("创建进程中.....\n"));
   	DWORD dwSessionID = WTSGetActiveConsoleSessionId();
   
   	//获取当前处于活动状态用户的Token
   	if (!WTSQueryUserToken(dwSessionID, &hToken)) {
   		int nCode = GetLastError();
   		log_e(_T("获取用户token失败,错误码:%d\n"), nCode);
   		CloseHandle(hToken);
   		return FALSE;
   	}
   
   	//复制新的Token
   	if (!DuplicateTokenEx(hToken, MAXIMUM_ALLOWED, NULL, SecurityIdentification, TokenPrimary, &hTokenDup)) {
   		int nCode = GetLastError();
   		log_e(_T("复制用户token失败,错误码:%d\n"), nCode);
   
   		CloseHandle(hToken);
   		return FALSE;
   	}
   
   	//创建环境信息
   	if (!CreateEnvironmentBlock(&pEnv, hTokenDup, FALSE)) {
   		DWORD nCode = GetLastError();
   		log_e(_T("创建环境信息失败,错误码:%d\n"), nCode);
   		CloseHandle(hTokenDup);
   		CloseHandle(hToken);
   		return FALSE;
   	}
   
   	ZeroMemory(&si, sizeof(STARTUPINFO));
   	si.cb = sizeof(STARTUPINFO);
   	si.lpDesktop = _T("winsta0\\default");
   
   	ZeroMemory(&pi, sizeof(PROCESS_INFORMATION));
   
   	//开始创建进程
   	DWORD dwCreateFlag = NORMAL_PRIORITY_CLASS | CREATE_NEW_CONSOLE | CREATE_UNICODE_ENVIRONMENT;
   
   
   	if (!CreateProcessAsUser(hTokenDup, NULL, commandLine, NULL, NULL, FALSE, dwCreateFlag, pEnv, GetFullDir(), &si, &pi))
   	{
   		DWORD nCode = GetLastError();
   		log_e(_T("创建进程失败,错误码:%d\n"), nCode);
   		DestroyEnvironmentBlock(pEnv);
   		CloseHandle(hTokenDup);
   		CloseHandle(hToken);
   		return FALSE;
   	}
   	//创建一个进程
   	return TRUE;
   }
   ```

   - 注意:涉及到字符串的都要使用宽字符

# 三、总结

如果想知道怎么创建服务的朋友可以看我的另外的一篇博文[创建windows服务](https://onew.me/2018/10/08/windows-service/).有什么疑问可以多多交流.
