import ctypes as c
from ctypes import wintypes as w
from pathlib import Path
k=c.WinDLL('kernel32',use_last_error=True); ps=c.WinDLL('psapi',use_last_error=True)
def api(d,name,restype,args):
    f=getattr(d,name); f.restype=restype; f.argtypes=args; return f
P=c.c_void_p; Z=c.c_size_t
op=api(k,'OpenProcess',P,[w.DWORD,w.BOOL,w.DWORD])
close=api(k,'CloseHandle',w.BOOL,[P])
va=api(k,'VirtualAllocEx',P,[P,P,Z,w.DWORD,w.DWORD])
vf=api(k,'VirtualFreeEx',w.BOOL,[P,P,Z,w.DWORD])
wr=api(k,'WriteProcessMemory',w.BOOL,[P,P,P,Z,P])
thread=api(k,'CreateRemoteThread',P,[P,P,Z,P,P,w.DWORD,P])
wait=api(k,'WaitForSingleObject',w.DWORD,[P,w.DWORD])
enum=api(ps,'EnumProcessModules',w.BOOL,[P,P,w.DWORD,P])
name=api(ps,'GetModuleFileNameExW',w.DWORD,[P,P,w.LPWSTR,w.DWORD])
class Counters(c.Structure):
    _fields_=[('cb',w.DWORD),('faults',w.DWORD)]+[(x,Z) for x in ['peakWS','workingSet','peakPaged','paged','peakNonpaged','nonpaged','pagefile','peakPagefile','private']]
mem=api(ps,'GetProcessMemoryInfo',w.BOOL,[P,P,w.DWORD])
def memory(pid):
    h=op(0x410,False,pid); v=Counters(); v.cb=c.sizeof(v)
    try:
        if not mem(h,c.byref(v),v.cb): raise c.WinError(c.get_last_error())
        return {'private':v.private,'workingSet':v.workingSet}
    finally: close(h)
class MBI(c.Structure):
    _fields_=[('base',P),('allocationBase',P),('allocationProtect',w.DWORD),('partition',w.WORD),('size',Z),('state',w.DWORD),('protect',w.DWORD),('type',w.DWORD)]
vq=api(k,'VirtualQueryEx',Z,[P,P,P,Z])
def regions(pid):
    h=op(0x410,False,pid); address=0; result=[]
    try:
        while True:
            b=MBI()
            if not vq(h,address,c.byref(b),c.sizeof(b)): break
            if b.state==0x1000:
                result.append({'base':b.base,'allocationBase':b.allocationBase,'size':b.size,'protect':b.protect,'type':b.type})
            address=(b.base or 0)+b.size
        return result
    finally: close(h)
def modules(h):
    arr=(P*1024)(); needed=w.DWORD()
    if not enum(h,arr,c.sizeof(arr),c.byref(needed)): raise c.WinError(c.get_last_error())
    result={}
    for a in arr[:needed.value//c.sizeof(P)]:
        b=c.create_unicode_buffer(32768); name(h,a,b,len(b)); result[Path(b.value).name.lower()]=a
    return result
def call(h,fn,text):
    b=c.create_unicode_buffer(str(text)); a=va(h,None,c.sizeof(b),0x3000,4)
    if not a: raise c.WinError(c.get_last_error())
    try:
        if not wr(h,a,b,c.sizeof(b),None): raise c.WinError(c.get_last_error())
        t=thread(h,None,0,fn,a,0,None)
        if not t: raise c.WinError(c.get_last_error())
        try:
            if wait(t,20000)!=0: raise RuntimeError('remote call timeout')
        finally: close(t)
    finally: vf(h,a,0,0x8000)
def snapshot(pid,out):
    h=op(0x43a,False,pid)
    if not h: raise c.WinError(c.get_last_error())
    try:
        dll=Path(__file__).parent/'heap-snapshot.dll'
        mods=modules(h)
        if dll.name not in mods:
            local=c.WinDLL('kernel32'); base=mods['kernel32.dll']
            offset=c.cast(local.LoadLibraryW,P).value-local._handle
            call(h,base+offset,dll.resolve())
            mods=modules(h)
        local=c.WinDLL(str(dll.resolve()))
        fn=mods[dll.name]+c.cast(local.Snapshot,P).value-local._handle
        call(h,fn,out.resolve())
    finally: close(h)
