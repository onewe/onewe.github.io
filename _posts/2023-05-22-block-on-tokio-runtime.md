---
title: 我是如何把 Tokio Runtime 给卡死的
date: 2023/05/22 15:55:12
tags:
- nacos
- rust
- tokio
categories: rust
author: 
  nick: onew
  link: https://onew.me
subtitle: tokio runtime 神秘卡死事件.
---

# 一、前言

最近在忙着做 [nacos-sdk-rust](https://github.com/nacos-group/nacos-sdk-rust) `3.x`  版本的重构, 在重构的过程中一切都很顺利, 但是后面的验证过程中, 发现程序每隔 30 分钟就会卡死, 心跳也不发了. 这就很奇怪了. 于是就研究了一下 `tokio` 的调度机制. 



# 二、给你一段卡死的代码

```rust

    #[tokio::test(flavor = "multi_thread", worker_threads = 8)]
    pub async fn test_switch() {
        let mut handles = Vec::new();

        handles.push(tokio::spawn({
            async {
                loop {
                    println!("{:?}: loop task 1", thread::current().id());
                    tokio::time::sleep(Duration::from_secs(10)).await;
                }
            }
        }));
        handles.push(tokio::spawn({
            async {
                loop {
                    println!("{:?}: loop task 2", thread::current().id());
                    tokio::time::sleep(Duration::from_secs(10)).await;
                }
            }
        }));

        handles.push(tokio::spawn({
            async {
                let mut count = 0;
                loop {
                    println!("{:?}: loop task 3, task count: {}", thread::current().id(), count);
                    
                    if count > 3 {
                        let (tx, rx) = std::sync::mpsc::channel::<String>();
                        tokio::spawn(async move{
                            let _ = tx.send("send message".to_string());
                        });
                        let ret = rx.recv().unwrap();

                        println!("receive message :{} , task count :{}", ret, count);
                    }

                    tokio::time::sleep(Duration::from_secs(5)).await;
                    count += 1;
                }
            }
        }));

        for handle in handles {
            handle.await.expect("handle await");
        }
    }
```

在遇到定时执行任务的情况, 我相信大多数人的写法都和上面的写法差不多. 看着好像没啥问题对吧. 下面是运行日志

```
running 1 test
ThreadId(10): loop task 1
ThreadId(7): loop task 3, task count: 0
ThreadId(9): loop task 2
ThreadId(10): loop task 3, task count: 1
ThreadId(10): loop task 3, task count: 2
ThreadId(6): loop task 1
ThreadId(10): loop task 2
ThreadId(4): loop task 3, task count: 3
ThreadId(4): loop task 1
ThreadId(10): loop task 2
ThreadId(4): loop task 3, task count: 4
```

在程序跑到  `ThreadId(4): loop task 3, task count: 4`  时后面的任务就不执行了, 好像所有的任务都暂停了一样. 是的, 我们成功的把 `tokio `的  `wroker` 全部卡死了. 从这里引出 2 个问题:

- 为什么 `let ret = rx.recv().unwrap();` 这行代码为什么被阻塞, `let _ = tx.send("send message".to_string());` 没有被执行吗?
- 为什么其他定时任务不执行了?





# 三、被阻塞的代码

```rust
let (tx, rx) = std::sync::mpsc::channel::<String>();
tokio::spawn(async move{
    let _ = tx.send("send message".to_string());
});
let ret = rx.recv().unwrap();
```

这里明明通过 `tokio::spawn` 派生了一个任务, 为什么不执行呢? 这里就要看看 `tokio` 的任务调度逻辑了

```rust
		#[track_caller]
    pub fn spawn<T>(future: T) -> JoinHandle<T::Output>
    where
        T: Future + Send + 'static,
        T::Output: Send + 'static,
    {
        // preventing stack overflows on debug mode, by quickly sending the
        // task to the heap.
      	// 省略无关的代码 ..
       spawn_inner(future, None)
    }

    #[track_caller]
    pub(super) fn spawn_inner<T>(future: T, name: Option<&str>) -> JoinHandle<T::Output>
    where
        T: Future + Send + 'static,
        T::Output: Send + 'static,
    {
        use crate::runtime::{task, context};
      	// 生产 task id
        let id = task::Id::next();
      	// 获取当前上下文中的 Spawner 
        let spawn_handle = context::spawn_handle().expect(CONTEXT_MISSING_ERROR);
      	// 创建 task
        let task = crate::util::trace::task(future, "task", name, id.as_u64());
        spawn_handle.spawn(task, id)
    }

	// 重点在 spawner 这里

impl Spawner {
    /// Spawns a future onto the thread pool
    pub(crate) fn spawn<F>(&self, future: F, id: task::Id) -> JoinHandle<F::Output>
    where
        F: crate::future::Future + Send + 'static,
        F::Output: Send + 'static,
    {
      	// 绑定一个 task
        worker::Shared::bind_new_task(&self.shared, future, id)
    }
}

impl Shared {
  
  
    pub(super) fn bind_new_task<T>(
        me: &Arc<Self>,
        future: T,
        id: crate::runtime::task::Id,
    ) -> JoinHandle<T::Output>
    where
        T: Future + Send + 'static,
        T::Output: Send + 'static,
    {
     
			// 省略无关代码, 任务调度
     	me.schedule(notified, false);
    }

    pub(super) fn schedule(&self, task: Notified, is_yield: bool) {
        CURRENT.with(|maybe_cx| {
            if let Some(cx) = maybe_cx {
                // 判断当前 thread 中是否有 runtime 的上下文
                if self.ptr_eq(&cx.worker.shared) {
                    // 判断上下文中是否有 core 对象
                    if let Some(core) = cx.core.borrow_mut().as_mut() {
                      	// 优先把 task 在此线程的 worker 中进行调度
                        self.schedule_local(core, task, is_yield);
                        return;
                    }
                }
            }

            // 否则加入全局任务队列
            self.inject.push(task);
        })
    }

    fn schedule_local(&self, core: &mut Core, task: Notified, is_yield: bool) {
       

        // 这里的 is_yield 为 false 并且 config.disable_lifo_slot 未禁用 lifo_slot
        let should_notify = if is_yield || self.config.disable_lifo_slot {
            core.run_queue
                .push_back(task, &self.inject, &mut core.metrics);
            true
        } else {
            // 获取 lifo_slot 槽中是否有任务
          	
            let prev = core.lifo_slot.take();
            let ret = prev.is_some();
						
          	// 如果有任务 把上一个任务推到 本地任务队列中
          	// 并把当前任务放入到 lifo_slot 槽中
            if let Some(prev) = prev {
                core.run_queue
                    .push_back(prev, &self.inject, &mut core.metrics);
            }
						
          // 放入到 lifo_slot 槽中
            core.lifo_slot = Some(task);

            ret
        };
    }
}
```

我们在代码里进行了 `tokio::spawn` 操作, `tokio` 会把该任务放入到当前 `worker` 的 `FILO` 槽中， 而 `FILO` 槽中的任务是无法被其他 `worker` 所窃取的, 所以此任务要被执行要等当前执行的线程让出执行执行权然后 `worker` 重新轮训任务才会得到执行. 而我们这里直接一个 `tx.receive()` 这里的 `receive` 非 `tokio` 库中的 `receive` 而是标准库中的, 所以这里无法让 `worker` 回到 `tokio::rutnime` 中去重新执行任务, 只能在这里苦苦等待 `receive` 结果. 这个等待是不会有结果的, 因为与 `receive` 对应的 `send` 方法是永远不会被执行的.

# 四、Runtime 被卡死

`runtime` 被卡死的问题还是得回到 `tokio` 的任务调度中来, 所以还是来看看 `tokio` 任务调度的代码吧.

```rust
// 每个 worker 对应一个 Context
impl Context {
	
  fn run(&self, mut core: Box<Core>) -> RunResult {
    	// Core 是 worker 的核心数据结构 包含很多任务信息
    	// Core 里包含了 lifo_slot(用于减少任务调度延迟的 lifo_slot 优先执行 lifo_slot 中的任务) 和 run_queue (worker 专属的任务队列)
        while !core.is_shutdown {
            // Increment the tick
          	// 每循环一次增加一次 tick
          	// 改 tick 是用于判断是否需要强制 park 等待 readiness 事件
            core.tick();

          	// 当 tick 达到 31 的整数倍 则强制 park 等待 readiness 事件
            core = self.maintenance(core);

            // 获取任务的优先级如下:
          	// lifo_slot -> run_queue -> inject_queue
          	// 如果 tick 达到 61 的整数倍 优先级如下
          	// inject_queue -> lifo_slot -> run_queue
            if let Some(task) = core.next_task(&self.worker) {
                core = self.run_task(task, core)?;
                continue;
            }

            // 若 worker 处于空闲状态则 窃取 其他 worker 的任务
            if let Some(task) = core.steal_work(&self.worker) {
                core = self.run_task(task, core)?;
            } else {
                // 若未能 窃取到任务 则进行 park 等待 readiness 事件
                core = if did_defer_tasks() {
                    self.park_timeout(core, Some(Duration::from_millis(0)))
                } else {
                    self.park(core)
                };
            }
        }

        core.pre_shutdown(&self.worker);

        // Signal shutdown
        self.worker.handle.shutdown_core(core);
        Err(())
    }

}
```

以上代码就是 `tokio` 执行任务的核心逻辑, 回到 `Runtime` 被卡死的问题上, 这里导致问题的是 `park` 操作, 因为我们是使用 `tokio::sleep` , 在还没到达唤醒时间时, `worker` 处于 `park ` 状态.

```rust
impl Inner {
  	
      fn park(&self, handle: &driver::Handle) {
       	// 省略代码
        if let Some(mut driver) = self.shared.driver.try_lock() {
            self.park_driver(&mut driver, handle);
        } else {
            self.park_condvar();
        }
    }
  
}
```

上面的代码表示, 只能有一个 `worker` 能获得 `IO Driver` 资源, 其余的 `worker` 只能被 `park_condvar`, 而这 2 种 `park` 的区别在于, `park_driver` 能靠底层 `epoll` 或者 `kqueue` 机制被唤醒, 而 `park_condvar` 只能被其他的 ` worker` 唤醒. 所以被卡死的流程如下:

- 所有 `worker` 因为 `sleep`  被 `park` 住处于休眠状态, 其中一个 `worker` 持有 `IO Driver` 资源
- 当等待时间达到唤醒时间时, 持有 `IO Driver` 的 `worker` 会被 `epoll`或者`kqueue` 事件机制给唤醒
- `worker` 唤醒之后执行任务队列中的任务, 并唤醒其他的 `worker` , 如此往复直到 `loop task 3` 执行第四次时情况开始发生变化
- 因为 `loop task 3` 的 `sleep ` 时间短, 先于其他几个 `worker` 被唤醒, 唤醒之后由于没有其他的任务执行, 也没有去唤醒其他 `worker`, 然后执行自己的 `task`, 这里执行 `task` 就会被 `rx.recive` 给永远阻塞住(具体原因往上看)
- 由于这个唯一活着的 `worker` 被永远阻塞住了, 所以就算其余的 `task` 唤醒条件达到了也无法被唤醒然后继续执行, 那么我们的 `Runtime` 卡死目标达成

这里的情况与这个 ISSUE 类似: https://github.com/tokio-rs/tokio/issues/4730



# 五、总结

在 `tokio` 中尽量使用 `tokio` 中提供的 `channel` 和各种锁, 避免出现这种情况, 主要是这种情况并不好排查(本人能力有限), 如果有爱好 rust 的朋友, 欢迎一起来共建 [nacos-sdk-rust](https://github.com/nacos-group/nacos-sdk-rust)  来练手