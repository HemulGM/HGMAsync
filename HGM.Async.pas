unit HGM.Async;

interface

uses
  System.Classes, System.SysUtils, System.Threading;

type
  TOnExcept = reference to procedure(const Text: string);

  Async = class
  private
    class var
      FOnExcept: TOnExcept;
      FPool: TThreadPool;
    class procedure SetOnExcept(const Value: TOnExcept); static;
    class procedure DoExcept(E: Exception);
    class procedure Synchronize(Proc: TThreadProcedure);
    class procedure ForceQueue(Proc: TThreadProcedure); overload;
    class function IsMainThread: Boolean;
  public
    class property OnExcept: TOnExcept read FOnExcept write SetOnExcept;
  public
    type
      TProcObj = procedure of object;


      TProcObj<T> = procedure(Arg1: T) of object;


      TProcObjConst<T> = procedure(const Arg1: T) of object;


      TProcConst<T> = reference to procedure(const Arg1: T);


      TFuncObjConst<T, T2> = function(const Arg1: T): T2 of object;


      TFuncObjConst<T> = function: T of object;
  public    // Cancel
    class procedure CancelAll(Proc: TProc = nil);
    // Sync
    class function SyncRef<T>(Proc: TProc<T>): TProc<T>;
    class function Sync<T, T2>(Func: TFuncObjConst<T, T2>; Arg1: T): T2; overload;
    class function Sync<T>(Func: TFuncObjConst<T>): T; overload;
    class function Sync<T>(Func: TFunc<T>): T; overload;
    class procedure Sync(Proc: TProc); overload;
    class procedure Sync(Proc: TProcObj); overload;
    class procedure Sync<T>(Proc: TProc<T>; Arg1: T); overload;
    class procedure Sync<T, T2>(Proc: TProc<T, T2>; Arg1: T; Arg2: T2); overload;
    class procedure Sync<T>(Proc: TProcConst<T>; Arg1: T); overload;
    class procedure Sync<T>(Proc: TProcObj<T>; Arg1: T); overload;
    class procedure Sync<T>(Proc: TProcObjConst<T>; Arg1: T); overload;
    // Queue
    class function QueueRef<T>(Proc: TProc<T>): TProc<T>;
    class procedure Queue(Proc: TProc); overload;
    class procedure Queue(Proc: TProcObj); overload;
    class procedure Queue<T>(Proc: TProc<T>; Arg1: T); overload;
    class procedure Queue<T, T2>(Proc: TProc<T, T2>; Arg1: T; Arg2: T2); overload;
    class procedure Queue<T>(Proc: TProcConst<T>; Arg1: T); overload;
    class procedure Queue<T>(Proc: TProcObj<T>; Arg1: T); overload;
    class procedure Queue<T>(Proc: TProcObjConst<T>; Arg1: T); overload;
    class procedure Queue<T, T2>(Func: TFuncObjConst<T, T2>; Arg1: T); overload;
    // Task
    class function Run(Proc: TProc; AfterSync: TProc = nil): ITask; overload;
    class function Run<T>(Proc: TFunc<T>; AfterSync: TProc<T> = nil): ITask; overload;
    class function Run<T>(Proc: TProc<T>; Arg1: T; AfterSync: TProc = nil): ITask; overload;
    class function Run<T>(Proc: TProcObj<T>; Arg1: T; AfterSync: TProc = nil): ITask; overload;
    class function Run<T>(Proc: TProcObjConst<T>; Arg1: T; AfterSync: TProc = nil): ITask; overload;
    class function Run<T, TResult>(Proc: TFunc<T, TResult>; Arg1: T; AfterSync: TProc<TResult> = nil): ITask; overload;
  end;

implementation

class procedure Async.SetOnExcept(const Value: TOnExcept);
begin
  FOnExcept := Value;
end;

class procedure Async.DoExcept(E: Exception);
begin
  if Assigned(FOnExcept) then
    FOnExcept('Async error: ' + E.Message);
end;

class function Async.IsMainThread: Boolean;
begin
  Result := TThread.Current.ThreadID = MainThreadID;
end;

class procedure Async.CancelAll(Proc: TProc);
var
  OldPool: TThreadPool;
begin
  OldPool := FPool;
  FPool := TThreadPool.Create;
  // Освобождение пула и ожидание завершения потоков делаем в отдельном потоке вне пулов
  TThread.RemoveQueuedEvents(TThread.Current);
  TThread.CreateAnonymousThread(
    procedure
    begin
      OldPool.Free;
      if Assigned(Proc) then
        Queue(Proc);
    end).Start;
end;

class procedure Async.Synchronize(Proc: TThreadProcedure);
begin
  TThread.Synchronize(nil, Proc);
end;

class procedure Async.ForceQueue(Proc: TThreadProcedure);
begin
  TThread.ForceQueue(nil, Proc);
end;

class procedure Async.Sync(Proc: TProcObj);
begin
  if not IsMainThread then
    Synchronize(Proc)
  else
    Proc;
end;

class procedure Async.Sync(Proc: TProc);
begin
  if not IsMainThread then
    Synchronize(
      procedure
      begin
        try
          Proc;
        except
          on E: Exception do
            DoExcept(E);
        end;
      end)
  else
    Proc;
end;

class procedure Async.Sync<T>(Proc: TProc<T>; Arg1: T);
begin
  if not IsMainThread then
    Sync(
      procedure
      begin
        Proc(Arg1);
      end)
  else
    Proc(Arg1);
end;

class function Async.SyncRef<T>(Proc: TProc<T>): TProc<T>;
begin
  Result :=
    procedure(Arg1: T)
    begin
      Sync<T>(Proc, Arg1);
    end;
end;

class function Async.Sync<T, T2>(Func: TFuncObjConst<T, T2>; Arg1: T): T2;
var
  FResult: T2;
begin
  if not IsMainThread then
  begin
    Synchronize(
      procedure
      begin
        FResult := Func(Arg1);
      end);
    Result := FResult;
  end
  else
    Exit(Func(Arg1));
end;

class procedure Async.Sync<T, T2>(Proc: TProc<T, T2>; Arg1: T; Arg2: T2);
begin
  if not IsMainThread then
    Synchronize(
      procedure
      begin
        Proc(Arg1, Arg2);
      end)
  else
    Proc(Arg1, Arg2);
end;

class procedure Async.Sync<T>(Proc: TProcObjConst<T>; Arg1: T);
begin
  if not IsMainThread then
    Synchronize(
      procedure
      begin
        Proc(Arg1);
      end)
  else
    Proc(Arg1);
end;

class function Async.Sync<T>(Func: TFunc<T>): T;
var
  FResult: T;
begin
  if not IsMainThread then
  begin
    Synchronize(
      procedure
      begin
        FResult := Func;
      end);
    Result := FResult;
  end
  else
    Exit(Func);
end;

class function Async.Sync<T>(Func: TFuncObjConst<T>): T;
var
  FResult: T;
begin
  if not IsMainThread then
  begin
    Synchronize(
      procedure
      begin
        FResult := Func;
      end);
    Result := FResult;
  end
  else
    Exit(Func);
end;

class procedure Async.Sync<T>(Proc: TProcConst<T>; Arg1: T);
begin
  if not IsMainThread then
    Synchronize(
      procedure
      begin
        Proc(Arg1);
      end)
  else
    Proc(Arg1);
end;

class procedure Async.Sync<T>(Proc: TProcObj<T>; Arg1: T);
begin
  if not IsMainThread then
    Synchronize(
      procedure
      begin
        Proc(Arg1);
      end)
  else
    Proc(Arg1);
end;

class function Async.Run(Proc, AfterSync: TProc): ITask;
begin
  Result := TTask.Run(
    procedure
    begin
      try
        try
          Proc;
        finally
          if Assigned(AfterSync) then
            Queue(AfterSync);
        end;
      except
        on E: Exception do
          DoExcept(E);
      end;
    end, FPool);
end;

class function Async.Run<T, TResult>(Proc: TFunc<T, TResult>; Arg1: T; AfterSync: TProc<TResult>): ITask;
begin
  Result := TTask.Run(
    procedure
    var
      FResult: TResult;
    begin
      try
        FResult := Proc(Arg1);
      finally
        if Assigned(AfterSync) then
          Queue<TResult>(AfterSync, FResult);
      end;
    end, FPool);
end;

class function Async.Run<T>(Proc: TProcObjConst<T>; Arg1: T; AfterSync: TProc): ITask;
begin
  Result := TTask.Run(
    procedure
    var
      FResult: T;
    begin
      try
        Proc(Arg1);
      finally
        if Assigned(AfterSync) then
          Queue(AfterSync);
      end;
    end, FPool);
end;

class function Async.Run<T>(Proc: TProcObj<T>; Arg1: T; AfterSync: TProc): ITask;
begin
  Result := TTask.Run(
    procedure
    var
      FResult: T;
    begin
      try
        Proc(Arg1);
      finally
        if Assigned(AfterSync) then
          Queue(AfterSync);
      end;
    end, FPool);
end;

class function Async.Run<T>(Proc: TProc<T>; Arg1: T; AfterSync: TProc = nil): ITask;
begin
  Result := TTask.Run(
    procedure
    var
      FResult: T;
    begin
      try
        Proc(Arg1);
      finally
        if Assigned(AfterSync) then
          Queue(AfterSync);
      end;
    end, FPool);
end;

class function Async.Run<T>(Proc: TFunc<T>; AfterSync: TProc<T>): ITask;
begin
  Result := TTask.Run(
    procedure
    var
      FResult: T;
    begin
      try
        FResult := Proc;
      finally
        if Assigned(AfterSync) then
          Queue<T>(AfterSync, FResult);
      end;
    end, FPool);
end;

class procedure Async.Queue(Proc: TProc);
begin
  ForceQueue(
    procedure
    begin
      Proc;
    end);
end;

class procedure Async.Queue<T>(Proc: TProc<T>; Arg1: T);
begin
  Queue(
    procedure
    begin
      Proc(Arg1);
    end);
end;

class function Async.QueueRef<T>(Proc: TProc<T>): TProc<T>;
begin
  Result :=
    procedure(Arg1: T)
    begin
      Queue<T>(Proc, Arg1);
    end;
end;

class procedure Async.Queue(Proc: TProcObj);
begin
  ForceQueue(
    procedure
    begin
      Proc;
    end);
end;

class procedure Async.Queue<T, T2>(Func: TFuncObjConst<T, T2>; Arg1: T);
begin
  ForceQueue(
    procedure
    begin
      Func(Arg1);
    end);
end;

class procedure Async.Queue<T, T2>(Proc: TProc<T, T2>; Arg1: T; Arg2: T2);
begin
  ForceQueue(
    procedure
    begin
      Proc(Arg1, Arg2);
    end);
end;

class procedure Async.Queue<T>(Proc: TProcObjConst<T>; Arg1: T);
begin
  ForceQueue(
    procedure
    begin
      Proc(Arg1);
    end);
end;

class procedure Async.Queue<T>(Proc: TProcConst<T>; Arg1: T);
begin
  ForceQueue(
    procedure
    begin
      Proc(Arg1);
    end);
end;

class procedure Async.Queue<T>(Proc: TProcObj<T>; Arg1: T);
begin
  ForceQueue(
    procedure
    begin
      Proc(Arg1);
    end);
end;

initialization
  Async.FPool := TThreadPool.Create;

finalization
  Async.FPool.Free;

end.

