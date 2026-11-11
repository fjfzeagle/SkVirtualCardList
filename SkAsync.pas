unit SkAsync;

{==============================================================================
  SkAsync - 基于 Delphi 原生 System.Threading 的轻量级流式异步执行器
  
  设计理念（KISS 原则与第一性原理）：
    1. 零第三方依赖：100% 基于 RTL 官方 System.Threading.TTask 与 TThreadPool；
    2. 弹性伸缩：按 CPU 核心按需分配工作线程，杜绝空转开销与常驻线程句柄泄漏；
    3. 线程安全切换：.OnSuccess 与 .OnError 回调自动通过 TThread.ForceQueue 安全投递至 UI 主线程；
    4. 零内存黑盒：不擅自 Free 业务数据对象，彻底杜绝悬空野指针；
    5. 闭环生命周期管理：通过闭包显式接口引用接力传递（LTaskHolder -> LQueueHolder），
       彻底解决 Delphi 嵌套匿名方法栈帧销毁及链式临时接口提前析构引发的 Access Violation。
==============================================================================}

interface

uses
  System.SysUtils, System.Classes, System.Threading, System.SyncObjs;

type
  IAsyncPromise<T> = interface
    ['{8A2B9C3D-4E5F-6A7B-8C9D-0E1F2A3B4C5D}']
    function OnSuccess(const ACallback: TProc<T>): IAsyncPromise<T>;
    function OnError(const ACallback: TProc<Exception>): IAsyncPromise<T>;
    function &Finally(const ACallback: TProc): IAsyncPromise<T>;
  end;

  TAsyncPromise<T> = class(TInterfacedObject, IAsyncPromise<T>)
  private
    FWorkerFunc: TFunc<T>;
    FSuccessCallback: TProc<T>;
    FErrorCallback: TProc<Exception>;
    FFinallyCallback: TProc;
    FResultValue: T;
    FException: Exception;
    FIsCompleted: Boolean;
    FLock: TCriticalSection;

    procedure TriggerCallbacks;
  public
    // 值传递 AWorkerFunc，强制触发编译器对匿名方法接口的 AddRef，杜绝临时接口提前析构
    constructor Create(AWorkerFunc: TFunc<T>);
    destructor Destroy; override;

    function OnSuccess(const ACallback: TProc<T>): IAsyncPromise<T>;
    function OnError(const ACallback: TProc<Exception>): IAsyncPromise<T>;
    function &Finally(const ACallback: TProc): IAsyncPromise<T>;
  end;

  TAsync = class
  public
    // 启动后台线程异步执行任务，并返回流式 Promise 接口 (值传递接管匿名方法生命周期)
    class function Run<T>(AWorkerFunc: TFunc<T>): IAsyncPromise<T>;
  end;

implementation

{ TAsync }

class function TAsync.Run<T>(AWorkerFunc: TFunc<T>): IAsyncPromise<T>;
begin
  Result := TAsyncPromise<T>.Create(AWorkerFunc);
end;

{ TAsyncPromise<T> }

constructor TAsyncPromise<T>.Create(AWorkerFunc: TFunc<T>);
var
  LTaskHolder: IAsyncPromise<T>;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FWorkerFunc := AWorkerFunc;
  FIsCompleted := False;
  FException := nil;

  // 1. 通过局部接口变量接管自身的强引用，确保进入闭包后 RefCount >= 1
  LTaskHolder := Self;

  // 2. 调度至系统级原生线程池
  TTask.Run(procedure
  var
    LQueueHolder: IAsyncPromise<T>;
    LFunc: TFunc<T>;
  begin
    try
      try
        // 核心：从堆对象字段取出工作委托执行，杜绝依赖任何栈帧残留
        LFunc := FWorkerFunc;
        if Assigned(LFunc) then
          FResultValue := LFunc();
      except
        on E: Exception do
          FException := Exception(AcquireExceptionObject);
      end;
    finally
      // 后台执行完毕后立即释放对业务委托的引用
      FWorkerFunc := nil;
      LFunc := nil;

      // 3. 将生命周期强引用安全接力转移至主线程队列闭包
      LQueueHolder := LTaskHolder;
      LTaskHolder := nil; // 释放子线程引用的闭包

      // 4. 将主线程回调排入 Windows/FMX 消息队列
      TThread.ForceQueue(nil, procedure
      begin
        try
          FLock.Enter;
          try
            FIsCompleted := True;
            TriggerCallbacks;
          finally
            FLock.Leave;
          end;
        finally
          // 5. 主线程所有回调执行完毕后，释放最后一份接口引用，ARC 平稳自然析构
          LQueueHolder := nil;
        end;
      end);
    end;
  end);
end;

destructor TAsyncPromise<T>.Destroy;
begin
  if FException <> nil then
    FException.Free;
  FLock.Free;
  inherited Destroy;
end;

function TAsyncPromise<T>.OnSuccess(const ACallback: TProc<T>): IAsyncPromise<T>;
begin
  FLock.Enter;
  try
    FSuccessCallback := ACallback;
    if FIsCompleted then
      TriggerCallbacks;
  finally
    FLock.Leave;
  end;
  Result := Self;
end;

function TAsyncPromise<T>.OnError(const ACallback: TProc<Exception>): IAsyncPromise<T>;
begin
  FLock.Enter;
  try
    FErrorCallback := ACallback;
    if FIsCompleted then
      TriggerCallbacks;
  finally
    FLock.Leave;
  end;
  Result := Self;
end;

function TAsyncPromise<T>.&Finally(const ACallback: TProc): IAsyncPromise<T>;
begin
  FLock.Enter;
  try
    FFinallyCallback := ACallback;
    if FIsCompleted then
      TriggerCallbacks;
  finally
    FLock.Leave;
  end;
  Result := Self;
end;

procedure TAsyncPromise<T>.TriggerCallbacks;
var
  LSuccess: TProc<T>;
  LError: TProc<Exception>;
  LFinally: TProc;
begin
  if not FIsCompleted then Exit;

  LSuccess := FSuccessCallback;
  LError := FErrorCallback;
  LFinally := FFinallyCallback;

  // 保证单次触发，防止重复调用
  FSuccessCallback := nil;
  FErrorCallback := nil;
  FFinallyCallback := nil;

  if FException <> nil then
  begin
    if Assigned(LError) then
      LError(FException);
  end
  else
  begin
    if Assigned(LSuccess) then
      LSuccess(FResultValue);
  end;

  if Assigned(LFinally) then
    LFinally();
end;

end.
