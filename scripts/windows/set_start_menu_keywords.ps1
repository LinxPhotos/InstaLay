# Sets System.Keywords (tags) on Start Menu .lnk files so Windows Search can
# match aliases while the visible shortcut name stays "InstaLay".
#
# Usage (Inno post-install):
#   powershell -NoProfile -ExecutionPolicy Bypass -File set_start_menu_keywords.ps1 `
#     -ShortcutPaths "C:\ProgramData\...\InstaLay.lnk" -Keywords Insta,Lay,Layout

param(
  [Parameter(Mandatory = $true)][string[]]$ShortcutPaths,
  [string[]]$Keywords = @('Insta', 'Lay', 'Layout', 'Instagram', 'instalay')
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential, Pack = 4)]
public struct PropertyKey {
  public Guid fmtid;
  public uint pid;
  public PropertyKey(Guid f, uint p) { fmtid = f; pid = p; }
}

[StructLayout(LayoutKind.Explicit, Size = 24)]
public struct PropVariant {
  [FieldOffset(0)] public ushort vt;
  [FieldOffset(8)] public IntPtr ptr;
  [FieldOffset(8)] public ulong uhVal;
}

[ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"),
 InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IPropertyStore {
  uint GetCount(out uint cProps);
  uint GetAt(uint iProp, out PropertyKey pkey);
  uint GetValue(ref PropertyKey key, out PropVariant pv);
  uint SetValue(ref PropertyKey key, ref PropVariant pv);
  uint Commit();
}

[ComImport, Guid("00021401-0000-0000-C000-000000000046")]
public class CShellLink { }

[ComImport, Guid("0000010b-0000-0000-C000-000000000046"),
 InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IPersistFile {
  void GetClassID(out Guid pClassID);
  [PreserveSig] int IsDirty();
  void Load([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, uint dwMode);
  void Save([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, bool fRemember);
  void SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string pszFileName);
  void GetCurFile(out IntPtr ppszFileName);
}

public static class LnkKeywords {
  static readonly PropertyKey PKEY_Keywords =
    new PropertyKey(new Guid("F29F85E0-4FF9-1068-AB91-08002B27B3D9"), 5);

  [DllImport("propsys.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
  static extern int InitPropVariantFromStringVector(
    [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.LPWStr)] string[] pcsz,
    uint cElems,
    out PropVariant ppropvar);

  [DllImport("ole32.dll")]
  static extern int PropVariantClear(ref PropVariant pvar);

  public static void Set(string lnkPath, string[] keywords) {
    var persist = (IPersistFile)new CShellLink();
    // STGM_READWRITE — Load(0) is read-only and Commit/Save then return STG_E_ACCESSDENIED.
    const uint STGM_READWRITE = 0x00000002;
    persist.Load(lnkPath, STGM_READWRITE);
    var store = (IPropertyStore)persist;

    PropVariant pv;
    int hr = InitPropVariantFromStringVector(keywords, (uint)keywords.Length, out pv);
    if (hr < 0) Marshal.ThrowExceptionForHR(hr);
    try {
      var key = PKEY_Keywords;
      hr = unchecked((int)store.SetValue(ref key, ref pv));
      if (hr < 0) Marshal.ThrowExceptionForHR(hr);
      hr = unchecked((int)store.Commit());
      if (hr < 0) Marshal.ThrowExceptionForHR(hr);
      persist.Save(lnkPath, true);
    } finally {
      PropVariantClear(ref pv);
    }
  }
}
'@

foreach ($path in $ShortcutPaths) {
  if (-not (Test-Path -LiteralPath $path)) {
    Write-Warning "Shortcut not found, skipping: $path"
    continue
  }
  [LnkKeywords]::Set((Resolve-Path -LiteralPath $path).Path, $Keywords)
  Write-Host "Keywords set on $path → $($Keywords -join ', ')"
}
