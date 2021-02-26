---
title: 在c/c++代码中执行bat文件
date: 2019/1/25 11:25:12
tags:
- windows c
- windows bat
categories: c
cover: https://gitee.com/oneww/onew_image/raw/master/windows_execute_bat_cover.jpg
author: 
  nick: onew
  link: https://onew.me
subtitle: windows服务执行bat文件
---



# 一、前言

最近在整公司IPC的更新功能,为了保证更新阶段的灵活性,思路为使用编写好的脚本进行更新,当更新失败的时候使用编写好的脚本进行回滚.感觉难度不是很大.但是在实现的过程中还是遇到了一个坑.



# 二、踩坑

当程序是以服务的方式运行的时候,我尝试过使用`system`、`ShellExecute`、`ShellExecuteEx`方式去执行写好的脚本,发现每次代码执行过后,脚本是没有被执行到的,但用vc调试的时候,发现是被执行了的.就感觉很奇怪了.貌似更windows的服务机制是有关的.具体的机制不太清楚,毕竟我只是一个javaer.抱着以解决问题为目的,在Stack Overflow上面找到了答案,使用创建进程的方式调用bat文件.下面开始贴代码了.



# 三、填坑

具体代码如下:

```c
/***
*执行批处理
*/
void execuBAT(TCHAR *batPath) {

	PROCESS_INFORMATION pi;
	STARTUPINFO si;
	ZeroMemory(&si, sizeof(si));
	si.cb = sizeof(si);
	si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
	if (CreateProcess(batPath, NULL, NULL, NULL, FALSE, CREATE_NO_WINDOW, NULL, NULL, &si, &pi)) {
		WaitForSingleObject(pi.hProcess, INFINITE);// 等待bat执行结束
		CloseHandle(pi.hProcess);
		CloseHandle(pi.hThread);
	}
}
```



# 四、总结

在当今百度已死的情况下,遇到问题去google 一下 还是会有不错的收获的.
