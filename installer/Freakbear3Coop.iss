#define MyAppName "Freakbear 3 Co-op"
#define MyAppVersion "0.8.6"
#define MyAppPublisher "NightSm4le"
#define MyAppURL "https://github.com/NightSm4le/frickbears3-coop"
#include "matrix.iss"

[Setup]
AppId={{ADD93545-418E-410D-B367-9F22F759F527}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppComments=Unofficial Co-op Modification for Freakbear 3.
DefaultDirName={code:GetDefaultGameDir}
DisableProgramGroupPage=yes
OutputDir=..\..\dist
OutputBaseFilename=Freakbear3Coop-{#MyAppVersion}-Setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
SetupLogging=yes
VersionInfoVersion={#MyAppVersion}
VersionInfoProductName={#MyAppName}
VersionInfoDescription=Freakbear 3 Co-op Installer
UninstallDisplayName={#MyAppName} {#MyAppVersion}
UninstallDisplayIcon={app}\Frickbears3.exe
InfoBeforeFile=info_before.txt
InfoAfterFile=info_after.txt
CloseApplications=no
AllowCancelDuringInstall=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "tools\xdelta3.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
Source: "patches\*.xdelta"; DestDir: "{tmp}"; Flags: deleteafterinstall
Source: "..\release_src\tmpl\Host.bat"; DestDir: "{app}"; Flags: onlyifdoesntexist uninsneveruninstall; Check: LogAdd('Host.bat')
Source: "..\release_src\tmpl\Join.bat"; DestDir: "{app}"; Flags: onlyifdoesntexist uninsneveruninstall; Check: LogAdd('Join.bat')
Source: "..\release_src\README_RU.txt"; DestDir: "{app}"; Flags: onlyifdoesntexist uninsneveruninstall; Check: LogAdd('README_RU.txt')
Source: "..\release_src\CONNECT_RU.md"; DestDir: "{app}"; Flags: onlyifdoesntexist uninsneveruninstall; Check: LogAdd('CONNECT_RU.md')
Source: "..\release_src\CUSTOM_CHARACTERS_RU.md"; DestDir: "{app}"; Flags: onlyifdoesntexist uninsneveruninstall; Check: LogAdd('CUSTOM_CHARACTERS_RU.md')
Source: "..\release_src\XDELTA_LICENSE.txt"; DestDir: "{app}"; Flags: onlyifdoesntexist uninsneveruninstall; Check: LogAdd('XDELTA_LICENSE.txt')
Source: "..\addons\CoopChars\*"; DestDir: "{app}\Addons\CoopChars"; Flags: onlyifdoesntexist uninsneveruninstall recursesubdirs

[Code]
var
  BaseName: String;
  BaseSha: String;
  BaseFile: String;
  Variant: String;
  OutSha: String;
  PatchName: String;
  Detected: Boolean;
  VariantPage: TInputOptionWizardPage;

function GetDefaultGameDir(Param: String): String;
begin
  Result := ExpandConstant('{userdesktop}');
end;

function Sha(const P: String): String;
begin
  Result := LowerCase(GetSHA256OfFile(P));
end;

function BaseNameForSha(const S: String): String;
begin
  Result := '';
  if S = '{#BaseSha_clean215}' then Result := 'clean215';
  if S = '{#BaseSha_coop072}' then Result := 'coop072';
  if S = '{#BaseSha_std082}' then Result := 'std082';
  if S = '{#BaseSha_unlock082}' then Result := 'unlock082';
end;

function OutShaFor(const B, V: String): String;
begin
  Result := '';
  if (B = 'clean215') and (V = 'std') then Result := '{#OutSha_clean215_std}';
  if (B = 'clean215') and (V = 'unlock') then Result := '{#OutSha_clean215_unlock}';
  if (B = 'coop072') and (V = 'std') then Result := '{#OutSha_coop072_std}';
  if (B = 'coop072') and (V = 'unlock') then Result := '{#OutSha_coop072_unlock}';
  if (B = 'std082') and (V = 'std') then Result := '{#OutSha_std082_std}';
  if (B = 'std082') and (V = 'unlock') then Result := '{#OutSha_std082_unlock}';
  if (B = 'unlock082') and (V = 'std') then Result := '{#OutSha_unlock082_std}';
  if (B = 'unlock082') and (V = 'unlock') then Result := '{#OutSha_unlock082_unlock}';
end;

function IsKnownOutput(const S: String): Boolean;
begin
  Result :=
    (S = '{#OutSha_clean215_std}') or (S = '{#OutSha_clean215_unlock}') or
    (S = '{#OutSha_coop072_std}') or (S = '{#OutSha_coop072_unlock}') or
    (S = '{#OutSha_std082_std}') or (S = '{#OutSha_std082_unlock}') or
    (S = '{#OutSha_unlock082_std}') or (S = '{#OutSha_unlock082_unlock}');
end;

procedure LogLine(const S: String);
var
  L: AnsiString;
begin
  L := S;
  SaveStringToFile(WizardDirValue + '\coop_install_log.txt', L + #13#10, True);
end;

function LogAdd(const N: String): Boolean;
begin
  Result := not FileExists(WizardDirValue + '\' + N);
  if Result then LogLine('added ' + N);
end;

function GameIsRunning(): Boolean;
var
  R: Integer;
  T: AnsiString;
  F: String;
begin
  Result := False;
  F := ExpandConstant('{tmp}\tl.txt');
  if Exec(ExpandConstant('{cmd}'), '/c tasklist /FI "IMAGENAME eq Frickbears3.exe" /NH > "' + F + '"', '', SW_HIDE, ewWaitUntilTerminated, R) then
    if LoadStringFromFile(F, T) then
      Result := Pos('Frickbears3.exe', T) > 0;
end;

procedure InitializeWizard();
begin
  Detected := False;
  VariantPage := CreateInputOptionPage(wpInfoBefore, 'Choose variant',
    'Which co-op build should be installed?',
    'Standard: normal co-op progression.'#13#10 +
    'Unlock All: all characters unlocked in co-op (separate save tag _coop_unlockall).',
    True, False);
  VariantPage.Add('Standard (recommended)');
  VariantPage.Add('Unlock All');
  VariantPage.SelectedValueIndex := 0;
  if ExpandConstant('{param:VARIANT|std}') = 'unlock' then
    VariantPage.SelectedValueIndex := 1;
end;

function DetectBase(var Err: String): Boolean;
var
  Dir, H, B: String;
begin
  Result := False;
  if Detected then
  begin
    Result := True;
    Exit;
  end;
  Dir := WizardDirValue;
  if not FileExists(Dir + '\Frickbears3.exe') then
  begin
    Err := 'This folder does not contain Frickbears3.exe. Select the game folder (v2.1.5).';
    Exit;
  end;
  if not FileExists(Dir + '\data.win') then
  begin
    Err := 'data.win was not found in this folder.';
    Exit;
  end;
  H := Sha(Dir + '\data.win');
  B := BaseNameForSha(H);
  if B <> '' then
  begin
    BaseName := B;
    BaseSha := H;
    BaseFile := Dir + '\data.win';
    if FileExists(Dir + '\data.win.coop-original') and (Sha(Dir + '\data.win.coop-original') <> H) then
    begin
      Err := 'An existing backup data.win.coop-original belongs to a different base version. Move it aside before installing so the restore point stays correct.';
      Exit;
    end;
  end
  else if IsKnownOutput(H) then
  begin
    if not FileExists(Dir + '\data.win.coop-original') then
    begin
      Err := 'Co-op is already installed but the original backup data.win.coop-original is missing, so the base version cannot be verified. Restore your original data.win manually first.';
      Exit;
    end;
    BaseSha := Sha(Dir + '\data.win.coop-original');
    BaseName := BaseNameForSha(BaseSha);
    if BaseName = '' then
    begin
      Err := 'The backup data.win.coop-original is not a supported base version.';
      Exit;
    end;
    BaseFile := Dir + '\data.win.coop-original';
  end
  else
  begin
    Err := 'Unsupported data.win (SHA-256 ' + H + ').'#13#10#13#10 +
      'Supported bases: clean v2.1.5, Coop_Install 0.7.2 (2.1.5), co-op 0.8.2, co-op 0.8.2 UnlockAll.'#13#10 +
      'Tester base 988a...: first apply the official v0.8.2 patch (it converts 988a to 0.8.2), then run this installer.';
    Exit;
  end;
  Variant := 'std';
  if VariantPage.SelectedValueIndex = 1 then Variant := 'unlock';
  OutSha := OutShaFor(BaseName, Variant);
  PatchName := 'p_' + BaseName + '_' + Variant + '.xdelta';
  LogLine('selected base=' + BaseName + ' variant=' + Variant + ' dir=' + Dir);
  Detected := True;
  Result := True;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Err: String;
begin
  Result := True;
  if CurPageID = wpSelectDir then
    if not DetectBase(Err) then
    begin
      MsgBox(Err, mbError, MB_OK);
      Result := False;
    end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Free, Total: Int64;
  Err: String;
begin
  Result := '';
  if not DetectBase(Err) then
    Result := Err
  else if GameIsRunning() then
    Result := 'Frickbear 3 is running. Close the game and run Setup again.'
  else if GetSpaceOnDisk64(ExtractFileDrive(WizardDirValue), Free, Total) and (Free < 100 * 1024 * 1024) then
    Result := 'Not enough free disk space (need ~100 MB for the staged patch and backup).';
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Src, NewWin, Staged: String;
  R: Integer;
  Ok: Boolean;
begin
  if CurStep = ssInstall then
  begin
    WizardForm.ProgressGauge.Position := 0;
    WizardForm.StatusLabel.Caption := 'Backing up original data.win...';
    if (BaseFile = WizardDirValue + '\data.win') and not FileExists(WizardDirValue + '\data.win.coop-original') then
    begin
      if not CopyFile(BaseFile, WizardDirValue + '\data.win.coop-original', False) then
      begin
        MsgBox('Could not create the backup data.win.coop-original. Nothing was changed.', mbError, MB_OK);
        Abort;
      end;
      LogLine('backup created from base ' + BaseName + ' ' + BaseSha);
    end;
    WizardForm.ProgressGauge.Position := 20;
    WizardForm.StatusLabel.Caption := 'Applying co-op patch (' + BaseName + ' / ' + Variant + ')...';
    Src := BaseFile;
    if BaseFile <> WizardDirValue + '\data.win' then
    begin
      Staged := ExpandConstant('{tmp}\base.win');
      if not CopyFile(BaseFile, Staged, False) then
      begin
        MsgBox('Could not stage the backup base. Nothing was changed.', mbError, MB_OK);
        Abort;
      end;
      Src := Staged;
    end;
    NewWin := ExpandConstant('{tmp}\data.win.new');
    ExtractTemporaryFile('xdelta3.exe');
    ExtractTemporaryFile(PatchName);
    Ok := Exec(ExpandConstant('{tmp}\xdelta3.exe'),
      '-d -f -s "' + Src + '" "' + ExpandConstant('{tmp}\') + PatchName + '" "' + NewWin + '"',
      '', SW_HIDE, ewWaitUntilTerminated, R);
    if not Ok or (R <> 0) then
    begin
      MsgBox('xdelta3 failed (code ' + IntToStr(R) + '). The game was not changed.', mbError, MB_OK);
      Abort;
    end;
    WizardForm.ProgressGauge.Position := 60;
    WizardForm.StatusLabel.Caption := 'Verifying patched data.win...';
    if Sha(NewWin) <> OutSha then
    begin
      MsgBox('Patched file failed SHA-256 verification. The game was not changed.', mbError, MB_OK);
      Abort;
    end;
    WizardForm.ProgressGauge.Position := 80;
    WizardForm.StatusLabel.Caption := 'Installing patched data.win...';
    if not CopyFile(NewWin, WizardDirValue + '\data.win.coop-new', False) then
    begin
      MsgBox('Could not stage the new data.win. The game was not changed.', mbError, MB_OK);
      Abort;
    end;
    Ok := Exec(ExpandConstant('{cmd}'),
      '/c move /Y "' + WizardDirValue + '\data.win.coop-new" "' + WizardDirValue + '\data.win"',
      '', SW_HIDE, ewWaitUntilTerminated, R);
    if not Ok or (R <> 0) then
    begin
      MsgBox('Could not replace data.win. The game was not changed.', mbError, MB_OK);
      Abort;
    end;
    WizardForm.ProgressGauge.Position := 95;
    LogLine('installed 0.8.6 variant=' + Variant + ' base=' + BaseName + ' out=' + OutSha);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Dir, B, N: String;
  R: Integer;
  L: AnsiString;
  Lines: TStringList;
  I: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    Dir := ExpandConstant('{app}');
    B := Dir + '\data.win.coop-original';
    if FileExists(B) then
    begin
      if UninstallSilent or (MsgBox('Restore the original (unmodded) data.win from data.win.coop-original?', mbConfirmation, MB_YESNO) = IDYES) then
      begin
        if Exec(ExpandConstant('{cmd}'), '/c copy /Y "' + B + '" "' + Dir + '\data.win"', '', SW_HIDE, ewWaitUntilTerminated, R) and (R = 0) then
        begin
          L := 'uninstall: original data.win restored from backup';
          SaveStringToFile(Dir + '\coop_install_log.txt', L + #13#10, True);
        end
        else
          MsgBox('Restore failed. Your backup is still at ' + B, mbError, MB_OK);
      end;
    end;
    if FileExists(Dir + '\coop_install_log.txt') then
    begin
      Lines := TStringList.Create;
      try
        if LoadStringFromFile(Dir + '\coop_install_log.txt', L) then
        begin
          Lines.Text := L;
          for I := 0 to Lines.Count - 1 do
          begin
            N := Lines[I];
            if Pos('added ', N) = 1 then
            begin
              N := Copy(N, 7, Length(N));
              if FileExists(Dir + '\' + N) then DeleteFile(Dir + '\' + N);
            end;
          end;
        end;
      finally
        Lines.Free;
      end;
    end;
  end;
end;