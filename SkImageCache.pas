unit SkImageCache;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Threading, System.Net.HttpClient, System.IOUtils, System.Hash,
  System.SyncObjs, System.Skia;

type
  TImageLoadedProc = reference to procedure;

  // 具备 LRU 淘汰、本地磁盘持久化、请求合并、并发限流与生命周期安全的图片缓存管理器
  TSkImageCache = class
  public const
    MAX_LRU_CAPACITY = 80;     // 内存最多驻留 80 张图片
    MAX_CONCURRENT_DOWNLOADS = 4; // 最大同时进行的网络下载数
  private
    type
      TCallbackInfo = record
        Owner: TObject;
        Proc: TImageLoadedProc;
      end;
  private
    class var FCache: TDictionary<string, ISkImage>;
    class var FLruOrder: TList<string>;
    class var FPendingCallbacks: TDictionary<string, TList<TCallbackInfo>>;
    class var FWaitingQueue: TList<string>;
    class var FActiveDownloads: Integer;
    class var FLock: TObject;
    class var FDiskCacheDir: string;
    class var FUnsubscribedOwners: TList<TObject>;
    class var FFailedUrls: TDictionary<string, UInt64>; // 失败冷却记录表 (防止弱网或404死循环重试)

    class constructor Create;
    class destructor Destroy;
    class procedure TouchLRU(const AUrl: string);
    class procedure PutImage(const AUrl: string; const AImage: ISkImage);
    class function GetDiskCacheFilePath(const AUrl: string): string;
    class procedure DispatchNextDownload;
    class procedure InternalDownloadUrl(const AUrl: string);
    class procedure NotifyLoaded(const AUrl: string);
  public
    // 获取图片：若命中内存直接返回；未命中则异步拉取并通知 AOnLoaded
    // AOwner 可传入请求者组件（如 TSkVirtualListView 实例），用于注销生命周期
    class function GetImage(const AUrl: string; const AOwner: TObject;
      const AOnLoaded: TImageLoadedProc): ISkImage;
    // 当组件销毁时调用，安全清理待触发的回调，防止访问已释放的内存
    class procedure Unsubscribe(const AOwner: TObject);
    // 清空内存缓存
    class procedure ClearMemoryCache;
    // 获取当前内存缓存数量
    class function MemoryCount: Integer;
  end;

implementation

{ TSkImageCache }

class constructor TSkImageCache.Create;
begin
  FCache := TDictionary<string, ISkImage>.Create;
  FLruOrder := TList<string>.Create;
  FPendingCallbacks := TDictionary<string, TList<TCallbackInfo>>.Create;
  FWaitingQueue := TList<string>.Create;
  FActiveDownloads := 0;
  FLock := TObject.Create;
  FUnsubscribedOwners := TList<TObject>.Create;
  FFailedUrls := TDictionary<string, UInt64>.Create;

  FDiskCacheDir := TPath.Combine(TPath.GetCachePath, 'SkiaImgCache');
  if not TDirectory.Exists(FDiskCacheDir) then
    ForceDirectories(FDiskCacheDir);
end;

class destructor TSkImageCache.Destroy;
var
  List: TList<TCallbackInfo>;
begin
  for List in FPendingCallbacks.Values do
    List.Free;
  FPendingCallbacks.Free;
  FWaitingQueue.Free;
  FCache.Free;
  FLruOrder.Free;
  FUnsubscribedOwners.Free;
  FFailedUrls.Free;
  FLock.Free;
end;

class function TSkImageCache.GetDiskCacheFilePath(const AUrl: string): string;
var
  UrlHash: string;
begin
  UrlHash := THashMD5.GetHashString(AUrl);
  Result := TPath.Combine(FDiskCacheDir, UrlHash + '.cache');
end;

class procedure TSkImageCache.TouchLRU(const AUrl: string);
begin
  FLruOrder.Remove(AUrl);
  FLruOrder.Add(AUrl);
end;

class procedure TSkImageCache.PutImage(const AUrl: string; const AImage: ISkImage);
var
  OldestUrl: string;
begin
  if AImage = nil then Exit;

  while FCache.Count >= MAX_LRU_CAPACITY do
  begin
    if FLruOrder.Count > 0 then
    begin
      OldestUrl := FLruOrder[0];
      FLruOrder.Delete(0);
      FCache.Remove(OldestUrl);
    end
    else
      Break;
  end;

  FCache.AddOrSetValue(AUrl, AImage);
  TouchLRU(AUrl);
end;

class function TSkImageCache.MemoryCount: Integer;
begin
  TMonitor.Enter(FLock);
  try
    Result := FCache.Count;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TSkImageCache.ClearMemoryCache;
begin
  TMonitor.Enter(FLock);
  try
    FCache.Clear;
    FLruOrder.Clear;
    FFailedUrls.Clear;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TSkImageCache.Unsubscribe(const AOwner: TObject);
var
  Url: string;
  CbList: TList<TCallbackInfo>;
  I: Integer;
begin
  if AOwner = nil then Exit;

  TMonitor.Enter(FLock);
  try
    FUnsubscribedOwners.Add(AOwner);
    for Url in FPendingCallbacks.Keys do
    begin
      CbList := FPendingCallbacks[Url];
      for I := CbList.Count - 1 downto 0 do
      begin
        if CbList[I].Owner = AOwner then
          CbList.Delete(I);
      end;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TSkImageCache.GetImage(const AUrl: string; const AOwner: TObject;
  const AOnLoaded: TImageLoadedProc): ISkImage;
var
  CbInfo: TCallbackInfo;
  CbList: TList<TCallbackInfo>;
  LastFailTime: UInt64;
begin
  Result := nil;
  if AUrl.Trim.IsEmpty then Exit;

  TMonitor.Enter(FLock);
  try
    // 0. 检查失败冷却记录表（20秒内失败过的 URL 暂不重复发起，防止网络风暴）
    if FFailedUrls.TryGetValue(AUrl, LastFailTime) then
    begin
      if TThread.GetTickCount64 - LastFailTime < 20000 then
        Exit;
      FFailedUrls.Remove(AUrl);
    end;

    // 1. 检查 L1 内存缓存
    if FCache.TryGetValue(AUrl, Result) then
    begin
      TouchLRU(AUrl);
      Exit;
    end;

    // 2. 未命中，记录回调订阅
    CbInfo.Owner := AOwner;
    CbInfo.Proc := AOnLoaded;

    if FPendingCallbacks.TryGetValue(AUrl, CbList) then
    begin
      // 正在排队或下载中，仅追加回调即可，避免重复发起请求
      if Assigned(AOnLoaded) then
        CbList.Add(CbInfo);
      Exit;
    end;

    CbList := TList<TCallbackInfo>.Create;
    if Assigned(AOnLoaded) then
      CbList.Add(CbInfo);
    FPendingCallbacks.Add(AUrl, CbList);

    // 3. 加入下载调度队列
    FWaitingQueue.Add(AUrl);
    DispatchNextDownload;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TSkImageCache.DispatchNextDownload;
var
  NextUrl: string;
begin
  // 必须在 FLock 保护下调用
  while (FActiveDownloads < MAX_CONCURRENT_DOWNLOADS) and (FWaitingQueue.Count > 0) do
  begin
    NextUrl := FWaitingQueue[0];
    FWaitingQueue.Delete(0);
    Inc(FActiveDownloads);
    InternalDownloadUrl(NextUrl);
  end;
end;

class procedure TSkImageCache.InternalDownloadUrl(const AUrl: string);
var
  DiskFile: string;
begin
  DiskFile := GetDiskCacheFilePath(AUrl);

  TTask.Run(procedure
  var
    LHttp: THTTPClient;
    LStream: TMemoryStream;
    LSkImage: ISkImage;
  begin
    LSkImage := nil;

    try
      // A. 先检查磁盘二级缓存
      if TFile.Exists(DiskFile) then
      begin
        try
          LSkImage := TSkImage.MakeFromEncodedFile(DiskFile);
        except
          LSkImage := nil;
        end;
      end;

      // B. 磁盘未命中，走 HTTP 下载
      if LSkImage = nil then
      begin
        LHttp := THTTPClient.Create;
        LStream := TMemoryStream.Create;
        try
          try
            LHttp.ConnectionTimeout := 8000;
            LHttp.ResponseTimeout := 8000;
            if LHttp.Get(AUrl, LStream).StatusCode = 200 then
            begin
              LStream.Position := 0;
              try
                LStream.SaveToFile(DiskFile);
              except
              end;

              LStream.Position := 0;
              LSkImage := TSkImage.MakeFromEncodedStream(LStream);
            end;
          except
            LSkImage := nil;
          end;
        finally
          LStream.Free;
          LHttp.Free;
        end;
      end;
    finally
      // 写入缓存并调度通知
      TMonitor.Enter(FLock);
      try
        if LSkImage <> nil then
        begin
          PutImage(AUrl, LSkImage);
          FFailedUrls.Remove(AUrl);
        end
        else
          FFailedUrls.AddOrSetValue(AUrl, TThread.GetTickCount64);

        Dec(FActiveDownloads);
        DispatchNextDownload;
      finally
        TMonitor.Exit(FLock);
      end;

      NotifyLoaded(AUrl);
    end;
  end);
end;

class procedure TSkImageCache.NotifyLoaded(const AUrl: string);
begin
  // 回到主线程安全执行回调
  TThread.Queue(nil, procedure
  var
    CbList: TList<TCallbackInfo>;
    Cb: TCallbackInfo;
    I: Integer;
    CanInvoke: Boolean;
  begin
    CbList := nil;
    TMonitor.Enter(FLock);
    try
      if FPendingCallbacks.TryGetValue(AUrl, CbList) then
        FPendingCallbacks.Remove(AUrl);
    finally
      TMonitor.Exit(FLock);
    end;

    if CbList = nil then Exit;

    try
      for I := 0 to CbList.Count - 1 do
      begin
        Cb := CbList[I];
        CanInvoke := True;
        if Cb.Owner <> nil then
        begin
          TMonitor.Enter(FLock);
          try
            if FUnsubscribedOwners.Contains(Cb.Owner) then
              CanInvoke := False;
          finally
            TMonitor.Exit(FLock);
          end;
        end;

        if CanInvoke and Assigned(Cb.Proc) then
        begin
          try
            Cb.Proc();
          except
          end;
        end;
      end;
    finally
      CbList.Free;
    end;
  end);
end;

end.
