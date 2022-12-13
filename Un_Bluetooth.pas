unit Un_Bluetooth;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Memo.Types,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo, IdTCPClient,
  {$IFDEF ANDROID}
    Androidapi.Jni.Bluetooth,
    Androidapi.JNI.JavaTypes,
    Androidapi.JNIBridge,
    AndroidApi.Helpers,
    Androidapi.JNI.Widget,
    Androidapi.JNI.GraphicsContentViewText,
  {$ENDIF}
  IdGlobal, FMX.ListBox, System.Bluetooth, IdURI, math;

type TBitmapArray = array of TBitmap;
  
type TPrinterCommands = class
     const
      HT  = $9;
      LF  = $0A;
      CR  = $0D;
      ESC = $1B;
      DLE = $10;
      GS  = $1D;
      FS  = $1C;
      STX = $02;
      US  = $1F;
      CAN = $18;
      CLR = $0C;
      EOT = $04;

      INIT = [27, 64];
      FEED_LINE = [10];

      SELECT_FONT_A = [20, 33, $0];

      SET_BAR_CODE_HEIGHT = [29,104,100];
      PRINT_BAR_CODE_1 = [29, 107, 2];
      SEND_NULL_BYTE = [$00];

      SELECT_PRINT_SHEET = [$1B, $63, $30, $02];
      FEED_PAPER_AND_CUT = [$1D, $56, 66, $00];

      SELECT_CYRILLIC_CHARACTER_CODE_TABLE = [$1B, $74, $11];

      //SELECT_BIT_IMAGE_MODE = [$1B, $2A, 33, -128, 0];
      SET_LINE_SPACING_24 = [$1B, $33, 24];
      SET_LINE_SPACING_30 = [$1B, $33, 30];

      TRANSMIT_DLE_PRINTER_STATUS = [$10, $04, $01];
      TRANSMIT_DLE_OFFLINE_PRINTER_STATUS = [$10, $04, $02];
      TRANSMIT_DLE_ERROR_STATUS = [$10, $04, $03];
      TRANSMIT_DLE_ROLL_PAPER_SENSOR_STATUS = [$10, $04, $04];

      //ESC_FONT_COLOR_DEFAULT = [$1B, 'r', $00];
      ESC_FONT_COLOR_DEFAULT = [$1B, 114, $00];
      FS_FONT_ALIGN = [$1C, $21, 1, $1B, $21, 1];
      //ESC_ALIGN_LEFT = [ $1b, 'a', $00 ];
      //ESC_ALIGN_RIGHT = [ $1b, 'a', $02 ];
      //ESC_ALIGN_CENTER = [ $1b, 'a', $01 ];
      ESC_ALIGN_LEFT   = [$1b, 97, $00];
      ESC_ALIGN_RIGHT  = [$1b, 97, $02];
      ESC_ALIGN_CENTER = [$1b, 97, $01];
      ESC_CANCEL_BOLD  = [$1B, $45, 0];

      ESC_ALIGN_CENTER2 = $1b9701;


      //*********************************************/
      ESC_HORIZONTAL_CENTERS = [$1B, $44, 20, 28, 00];
      ESC_CANCLE_HORIZONTAL_CENTERS = [$1B, $44, 00 ];
      //*********************************************/

      ESC_ENTER   = [$1B, $4A, $40];
      PRINTE_TEST = [$1D, $28, $41];
end;

type TPrintAlign = (Left,Center,Right);

Type TBluetoothPrint = class
      G_USE_SUNMI:boolean;
      device:string;
      {$IFDEF ANDROID}
      ostream:JOutputStream;
      function  ManagerConnected:Boolean;   //проверка соед с адаптером
      Function  ConnectDevice(targetMAC:string):boolean;  //подключиться к устройству
      function  GetMacDevice(Device: string): string; //получить mac адрес устройства
      procedure  GetAdapterList;    //получение списка сопряженных устройств

      Procedure TextPosition(Align:TPrintAlign);
      procedure PrintImage(bmp:TBitmap);
      procedure PrintOnBluetooth(text: string);
      procedure PrintOnBluetoothTest;

      constructor Create();
      destructor Destroy;
      {$ENDIF}
     private
     {$IFDEF ANDROID}
      uid:JUUID;
      fBluetoothManager: TBluetoothManager;
      fAdapter: TBluetoothAdapter;
      fPairedDevices: TBluetoothDeviceList;
      fRemoteDevice: TBluetoothDevice;

      jAdapter: JBluetoothAdapter;
      jremoteDevice: JBluetoothDevice;
      jSock: JBluetoothSocket;
      function  FindDevice(Device: string): TBluetoothDevice; //поиск устройства
      {$ENDIF}
     public
      AdapterList:TStrings;
end;

type TLanPrint = class
     private
       fLanClient:TIdTCPClient;
       function  ConnectLan():boolean;
     public
       procedure PrintImage(bmp:TBitmap);
       procedure PrintText(text: string);
       constructor Create(ip, port:string);
       destructor Destroy; override;
end;

procedure ShowMessageToast(const pMsg:String);


var
    blPrint:TBluetoothPrint;
    LanPrint:TLanPrint;
    Function ImageToCommandByte(bmp:TBitmap):TArray<Byte>;
    function ImageToByte(bmp:TBitmap):TArray<Byte>;
    function CutBitmapArray(inBmp:TBitMap):TBitmapArray;
    procedure strtobyte(ss:string;var sbytes:TIdBytes);
    //function DoPrintBitmap(const ABitmap : TBitmap):Tstrings;

implementation

uses Classes.Translator;

const
    CUT_PAPER:  TArray<byte> = [$1D, $56, $42, $00];
    BREAK_LINE: TArray<byte> = [$10, $13, $10, $13];

var TimePrintComplete:integer;

procedure ShowMessageToast(const pMsg:String);
begin
{$IF DEFINED(win32) or DEFINED(win64)}
  showmessage(pMsg);
{$ENDIF}
{$IF DEFINED(iOS) or DEFINED(ANDROID)}
  TThread.Synchronize(nil, procedure begin
                                       TJToast.JavaClass.makeText(TAndroidHelper.Context,StrToJCharSequence(pMsg), TJToast.JavaClass.LENGTH_LONG).show
                                     end);
{$ENDIF}
end;


function ResizeBitmap(inBmp:TBitMap;w,h,x,y:word):TBitmap;
var
  iRect : TRect;
  hh:word;
begin
  Result := TBitmap.Create;
  if y+h<inBmp.Height then
     hh:=H else
     hh:=inBmp.Height-Y;

  Result.Width := W;               //334
  Result.Height := hh;              //250
  iRect.Left := X;                 //0
  iRect.Top := Y;                  //0,250,500,750
  iRect.Width := W;                //334
  iRect.Height:=hh;
  Result.CopyFromBitmap(inBmp,iRect,0,0);
end;

function CutBitmapArray(inBmp:TBitMap):TBitmapArray;
const MaxHeight=200; 
var
  CountImage,i,y:integer;
begin
//  setLength(Result,0);
  countImage:=ceil(inBmp.Height/MaxHeight);
  setLength(Result,countImage);
  y:=0;
  for i:=0 to countImage-1 do begin
    result[i]:=ResizeBitmap(inBmp,inBmp.Width,MaxHeight,0,y);
    y:=y+MaxHeight;
  end;
end;


{$IFDEF ANDROID}
Function ByteArrayToJavaByte(buf:TArray<byte>):TJavaArray<byte>;
var i:integer;
    jByte:TJavaArray<byte>;
begin
  jByte := TJavaArray<Byte>.Create(length(buf));
  for i := 1 to length(buf) do
      jByte.Items[i]:=buf[i-1];

  result:=jByte;
end;


{$ENDIF}


function myBinaryStrToByte(binaryStr:string):byte;  //00001111 - 8бит
const 
  binaryArray: array[0..15] of string = ('0000','0001','0010','0011',
                                         '0100','0101','0110','0111',
                                         '1000','1001','1010','1011',
                                         '1100','1101','1110','1111'
                                        );
  hexStr = '0123456789ABCDEF';
var i:integer;
    hex,f4,b4:string;
    len:integer;
    str,ZeroStr:string;
begin
  //добавляем недостующие нули
  ZeroStr:='';
  len:=length(binaryStr);
  if len<8 then
      for I := 1 to 8-len do
      zeroStr:=ZeroStr+'0';
  str:=binaryStr+ZeroStr;

  f4:=copy(Str,0,4);
  b4:=copy(Str,5,8);
  for I := 0 to length(binaryArray) do
      if f4=binaryArray[i] then
         begin
           hex:=hex+hexstr[i+1];
           break;
         end;
  for I := 0 to length(binaryArray) do
      if b4=binaryArray[i] then
         begin
           hex:=hex+hexstr[i+1];
           break;
         end;
  result:=strtoint('$'+hex);
end;

function binaryListToByte(List:TStrings):TArray<byte>;
var i,j,n:integer;
    sb,str:string;
    buf:TArray<byte>;
begin
  n:=1;
  for I := 0 to list.Count-1 do
  begin
    sb:='';
    j:=1;
    repeat
     str:=copy(list[i],j,8);

     SetLength(Buf,n);
//     form1.memo1.Lines.Add(str);
     buf[n-1]:=myBinaryStrToByte(str);

     n:=n+1;
     j:=j+8;
    until j>=length(list[i]);
  end;
  result:=buf;
end;




Function ImageToCommandByte(bmp:TBitmap):TArray<Byte>;
var widthHexString,heightHexString:string;
    bmpWidth:integer;
    bmpHeight:integer;
    buf:TArray<Byte>;
begin
  if not Assigned(bmp) then exit;

  bmpWidth:=bmp.Width;
  bmpHeight:=bmp.Height;

  if bmpWidth mod 8 = 0 then
    widthHexString:=inttoHex(bmpWidth div 8,1)
  else
    widthHexString:=inttoHex(bmpWidth div 8+1,1);


 if length(widthHexString)>2 then
    begin
     showmessage('decodeBitmap error: width is too large');
     exit;
    end else
    if length(widthHexString)=1 then
       widthHexString:='0' + widthHexString;

 heightHexString:=inttoHex(bmpHeight,1);
 if length(heightHexString)>2 then
    begin
     showmessage('decodeBitmap error: height is too large');
     exit;
    end else
    if length(heightHexString)=1 then
       heightHexString:='0'+heightHexString;

 SetLength(buf,8);
 buf[0]:=$1D;
 buf[1]:=$76;
 buf[2]:=$30;
 buf[3]:=$00;
 buf[4]:=strtoint('$'+widthHexString);
 buf[5]:=$00;
 buf[6]:=strtoint('$'+heightHexString);
 buf[7]:=$00;

 result:=buf;
end;

function ImageToByte(bmp:TBitmap):TArray<Byte>;
var i,j:integer;
    sb:string;
    Pixel: TAlphaColor;
    BMPData: TBitmapData;
    r,g,b:integer;

    bmpWidth:integer;
    bmpHeight:integer;
    List:TStrings;
    ListByte:TArray<Byte>;
begin
 if not Assigned(bmp) then exit;

 bmpWidth:=bmp.Width;
 bmpHeight:=bmp.Height;



 List:=TStringList.Create;
 Bmp.Map(TMapAccess.Read, BMPData);
 for i := 0 to bmpHeight-1 do
 begin
   sb:='';
   for j := 0 to bmpWidth-1 do
   begin
     Pixel:=BMPData.GetPixel(j, i);
     r:=(pixel shr 16) and $ff;
     g:=(pixel shr 8) and $ff;
     b:=pixel and $ff;

     if (r>160) and (g>160) and (b>160)  then
         sb:=sb+'0'
     else
         sb:=sb+'1';
   end;
   list.Add(sb);
 end;
 bmp.Unmap(BMPData);

 //form1.memo1.Lines:=list;
 ListByte:=binaryListToByte(List);
 list.Free;

 result:=ListByte;
end;


function char_to_byte(str:char):Byte;
begin
  case str of
    'А':result:=192;
    'Б':result:=193;
    'В':result:=194;
    'Г':result:=195;
    'Д':result:=196;
    'Е':result:=197;
    'Ж':result:=198;
    'З':result:=199;
    'И':result:=200;
    'Й':result:=201;
    'К':result:=202;
    'Л':result:=203;
    'М':result:=204;
    'Н':result:=205;
    'О':result:=206;
    'П':result:=207;
    'Р':result:=208;
    'С':result:=209;
    'Т':result:=210;
    'У':result:=211;
    'Ф':result:=212;
    'Х':result:=213;
    'Ц':result:=214;
    'Ч':result:=215;
    'Ш':result:=216;
    'Щ':result:=217;
    'Ъ':result:=218;
    'Ы':result:=219;
    'Ь':result:=220;
    'Э':result:=221;
    'Ю':result:=222;
    'Я':result:=223;
    'а':result:=224;
    'б':result:=225;
    'в':result:=226;
    'г':result:=227;
    'д':result:=228;
    'е':result:=229;
    'ж':result:=230;
    'з':result:=231;
    'и':result:=232;
    'й':result:=233;
    'к':result:=234;
    'л':result:=235;
    'м':result:=236;
    'н':result:=237;
    'о':result:=238;
    'п':result:=239;
    'р':result:=240;
    'с':result:=241;
    'т':result:=242;
    'у':result:=243;
    'ф':result:=244;
    'х':result:=245;
    'ц':result:=246;
    'ч':result:=247;
    'ш':result:=248;
    'щ':result:=249;
    'ъ':result:=250;
    'ы':result:=251;
    'ь':result:=252;
    'э':result:=253;
    'ю':result:=254;
    'я':result:=255;
  else
    result:=ord(str);
  end;
end;

procedure strtobyte(ss:string;var sbytes:TIdBytes);
var
 I: Integer;
begin
 SetLength(sbytes,length(ss));
 for I := 0 to Length(ss)-1 do sbytes[i]:=char_to_byte(ss[i]);
end;

procedure strtobyte936(ss:string;var sbytes:TBytes);
var
// I: Integer;
 Enc:TEncoding;
begin
 try
  Enc:=TEncoding.GetEncoding(936);
  SetLength(sbytes,length(ss));

  sbytes:=Enc.GetBytes(ss);
  Enc.Free;
 finally

 end;
end;



{TfBluetooth}

{$IFDEF ANDROID}
constructor TBluetoothPrint.Create;
begin
  inherited;
  FBluetoothManager := TBluetoothManager.Current;
  AdapterList:=TStringList.Create;
  uid := TJUUID.JavaClass.fromString
        // (stringtojstring('AC51B5BE-791B-4FBD-B754-CFAFDDD2D08D'));
        //(stringtojstring('fffffffa-ffff-ffff-afaf-ffaf5affffaf')); //работает с телефоном
        (stringtojstring('00001101-0000-1000-8000-00805F9B34FB'));  //paloma free
        //(stringtojstring('0000110A-0000-1000-8000-00805F9B34FB'));

  //create list devices
  if ManagerConnected then
     begin
       FAdapter := FBluetoothManager.CurrentAdapter;
     //  GetAdapterList;
     end else
     if not FBluetoothManager.EnableBluetooth then exit;
end;

destructor TBluetoothPrint.Destroy;
begin
  if jSock.isConnected then
     jSock.close;
  AdapterList.Free;
  inherited;
end;


function TBluetoothPrint.ManagerConnected:Boolean;  //проверка соед с адаптером
begin
  Result := false;
  if FBluetoothManager.ConnectionState = TBluetoothConnectionState.Connected then
  begin
    //ShowMessageToast('Device discoverable as "'+FBluetoothManager.CurrentAdapter.AdapterName+'"');
    Result := True;
  end
  else
  begin
    Result := False;
    //ShowMessageToast('No Bluetooth device Found');
  end;
end;

Procedure TBluetoothPrint.GetAdapterList; //получение списка сопряженных устройств
var
  I: Integer;
begin
 try
   if ManagerConnected then
     begin
       AdapterList.Clear;
       FPairedDevices := FBluetoothManager.GetPairedDevices;
       if FPairedDevices.Count > 0 then
       for I:= 0 to FPairedDevices.Count - 1 do
           AdapterList.Add(FPairedDevices[I].DeviceName);
     end;
 except
   on E : Exception do
     begin
       ShowMessage(E.Message);
     end;
 end;
end;

Function TBluetoothPrint.ConnectDevice(targetMAC:string):boolean;
var deviceName:jString;
begin
  result:=false;

  if trim(targetMAC)='' then exit;

  jAdapter:=TJBluetoothAdapter.JavaClass.getDefaultAdapter;
  jRemoteDevice:=jAdapter.getRemoteDevice(stringtojstring(targetMAC));
  deviceName:=jRemoteDevice.getName;
  jSock:=jRemoteDevice.CreateRfcommSocketToServiceRecord(UID);
  try
    jSock.connect;
  except On e:Exception do
   begin
    ShowMessageToast(e.Message);
    Exit;
   end;
  end;

  if not jSock.isConnected then
    begin
      ShowMessageToast(TAppTranslator.GetParam('ErrToConnection')+' '+device);
      exit;
    end;
  //ShowMessageToast('Подключено!');
  Result:=true;
  ostream:=jSock.getOutputStream;           // record io streams
  ostream.write(ord(255)); //
  ostream.write(ord(255)); // get device id   (nur Chitanda)
  sleep(200);
end;

function TBluetoothPrint.FindDevice(Device: string): TBluetoothDevice;
var
  I: integer;
  LDevice: TBluetoothDevice;
begin
  Result := nil;
  FPairedDevices:=nil;
  try
    FPairedDevices := FBluetoothManager.GetPairedDevices(FBluetoothManager.CurrentAdapter);
  except on e:Exception do
   // showmessage('Ошибка '+E.ClassName+':'+e.Message);
  end;

  if FPairedDevices<>nil then
  begin
    for I := 0 to FPairedDevices.Count - 1 do
    begin
      LDevice := FPairedDevices.Items[I];
      if Device = LDevice.DeviceName then Exit(LDevice);
    end;

    FPairedDevices := FBluetoothManager.LastDiscoveredDevices;
    for I := 0 to FPairedDevices.Count - 1  do
    begin
      LDevice := FPairedDevices.Items[I];
      if Device = LDevice.DeviceName then Exit(LDevice);
    end;
  end;

  Result := nil;
end;

function TBluetoothPrint.GetMacDevice(Device: string): string;
var LDevice: TBluetoothDevice;
begin
  LDevice:=FindDevice(Device);
  if LDevice<>nil then result:=LDevice.Address;
end;

Procedure TBluetoothPrint.TextPosition(Align:TPrintAlign);
var jBytes: TJavaArray<Byte>;
begin
 jBytes:=TJavaArray<byte>.Create(3);
 jBytes.Items[0]:=$1B;
 jBytes.Items[1]:=$61;
 case Align of
  Left:  jBytes.Items[2]:=$00;
  Center:jBytes.Items[2]:=$01;
  Right: jBytes.Items[2]:=$02;
 end;

 ostream.write(jbytes);
end;

procedure TBluetoothPrint.PrintImage(bmp: TBitmap);
var i:integer;
    countImage:integer;
    img: TBitmapArray;
    command:TArray<byte>;
    jBytes: TJavaArray<Byte>;
    esc:TArray<byte>;
begin
 if bmp.IsEmpty then exit;

 img:=CutBitmapArray(bmp);  //разрезаем изображение и получаем массив изображений
 countImage:=length(img);

 TextPosition(Center);

 TimePrintComplete:=0;
 for i:=0 to CountImage-1 do
   begin
      TimePrintComplete:=TimePrintComplete+900;
      //command
      command:=ImageToCommandByte(img[i]);
      jBytes:=ByteArrayToJavaByte(command);
      ostream.write(jbytes);

      //image
      command:=ImageToByte(img[i]);
      jBytes:=ByteArrayToJavaByte(command);
      ostream.write(jbytes);
   end;

 //отступ в конце чека
 //jBytes:=ByteArrayToJavaByte(BREAK_LINE);
 //ostream.write(jbytes);
 jBytes:=ByteArrayToJavaByte(CUT_PAPER);
 ostream.write(jbytes);
end;


procedure TBluetoothPrint.printOnBluetooth(text: string);
var
  i:integer;
  sb:TIdBytes;
  sb936:TBytes;
  jBytes: TJavaArray<Byte>;
begin
   TextPosition(Left);

   if G_USE_SUNMI then
             begin
              strtobyte936(text,sb936);
              for i := 0 to Length(sb936)-1 do ostream.write(sb936[i]);
             end else
             begin
              strtobyte(text,sb);
              for i := 0 to Length(sb)-1 do
              ostream.write(sb[i]);
             end;


 //jBytes:=ByteArrayToJavaByte(BREAK_LINE);
 //ostream.write(jbytes);
 jBytes:=ByteArrayToJavaByte(CUT_PAPER);
 ostream.write(jbytes);
end;


procedure TBluetoothPrint.PrintOnBluetoothTest;
var s:string;
begin
 s:='QWERTYUIOP{}ASDFGHJKL:"|ZXCVBNM<>?qwertyuiop[]asdfghjkl;zxcvbnm,.ЯЧСМИТЬБЮйцукенгшщзхъфывапролджэ\ячсмитьбю.,!"№;%:?*()_+1234567890-=';
 try
   printOnBluetooth(s);
 except
   showmessage(TAppTranslator.GetParam('ErrTestPrint'));
 end;
end;

{$ENDIF}













//lan
constructor TLanPrint.Create(ip, port:string);
begin
//  inherited;
  fLanClient:=TIdTCPClient.Create;
  fLanClient.ConnectTimeout:=5000;
  fLanClient.ReadTimeout:=5000;
  fLanClient.Host:=ip;
  fLanClient.Port:=port.ToInteger;
  ConnectLan();
end;

destructor TLanPrint.Destroy;
begin
  if assigned(FLanClient) then FLanClient.Free;
  inherited;
end;

function TLanPrint.ConnectLan():boolean;
begin
TThread.CreateAnonymousThread(procedure
                              begin
                               try
                                 try
                                   FLanClient.Connect;
                                 finally
                                   if FLanClient.Connected then begin
                                      ShowMessageToast(TAppTranslator.GetParam('TestConnectOk')+' '+FLanClient.Host);
                                   end;
                                 end;
                               except on e:Exception do
                                   ShowMessageToast('Printer error. '+e.Message);
                               end;
                              end).Start;
TThread.CreateAnonymousThread(procedure
                              begin
                                sleep(1000);
                                FLanClient.Disconnect
                              end).Start;
end;

procedure TLanPrint.Printimage(bmp:TBitmap);
var img: TBitmapArray;
    countImage:integer;
    command:TArray<byte>;
begin
 if bmp.IsEmpty then exit;

 try
   fLanClient.Connect;
 except on e:Exception do
   ShowMessageToast('Printer error. '+e.Message);
 end;
 if not fLanClient.Connected then exit;

 img:=CutBitmapArray(bmp);  //разрезаем изображение и получаем массив изображений
 countImage:=length(img);

 //TextPosition(Center);

 TimePrintComplete:=0;
 for var i:=0 to CountImage-1 do
   begin
      TimePrintComplete:=TimePrintComplete+900;
      
      //command
      command:=ImageToCommandByte(img[i]);
      fLanClient.IOHandler.Write(TIdBytes(command));

      //image
      command:=ImageToByte(img[i]);
      fLanClient.IOHandler.Write(TIdBytes(command))
   end;

  //fLanClient.IOHandler.Write(TIdBytes(BREAK_LINE));
  fLanClient.IOHandler.Write(TIdBytes(CUT_PAPER));
 // fLanClient.IOHandler.Writeln();

  fLanClient.Disconnect;
end;


procedure TLanPrint.PrintText(text: string);
var
  sb:TIdBytes;
begin
 try
   fLanClient.Connect;
 except on e:Exception do
   ShowMessageToast('Printer error. '+e.Message);
 end;
 if not fLanClient.Connected then exit;

 strtobyte(text,sb);
 fLanClient.IOHandler.Write(sb);


 //fLanClient.IOHandler.Write(TIdBytes(BREAK_LINE));
 fLanClient.IOHandler.Write(TIdBytes(CUT_PAPER));
 //fLanClient.IOHandler.Writeln();

 fLanClient.Disconnect;
end;





initialization

//VertScroll:=TVertScroll.Create(nil);


finalization

FreeAndNil(blPrint);
FreeAndNil(LanPrint);

end.
