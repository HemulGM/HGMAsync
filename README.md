# HGMAsync
 Async wrapper

### Samples
```Pascal
Async.Sync(GlobalWaitBegin);

Async.Run<Boolean>(
  function: Boolean
  begin
    Result := LongWorkWithBooleanResult;
  end,
  procedure(Result: Boolean)
  begin
    try
      if Result then
      begin
        ShowAllFine;
      end
      else
        ShowError;
    finally
      GlobalWaitEnd;
    end;
  end);
```

```Pascal
Async.Run(ConnectChatAsync);
```

```Pascal
procedure TFormMain.LogAsync(const Text: string);
begin
  Async.Sync<string, integer>(MemoLog.Lines.Add, FormatDateTime('HH:NN:SS.ZZZZZZ', Now) + #13#10 + Text);
end;
```

```Pascal
GlobalWaitBegin;
Async.Run(LoadServersAsync, GlobalWaitEnd);
```
