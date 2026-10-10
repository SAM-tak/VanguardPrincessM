#define WIN32_LEAN_AND_MEAN
#define _CRT_SECURE_NO_WARNINGS
#include <windows.h>
#include <stdio.h>
#include <dbghelp.h>
#include "MinHook.h"

typedef LONG (NTAPI *AllocFn)(HANDLE,void **,ULONG_PTR,SIZE_T *,ULONG,ULONG);
typedef LONG (NTAPI *AllocExFn)(HANDLE,void **,SIZE_T *,ULONG,ULONG,void *,ULONG);
typedef LONG (NTAPI *MapFn)(HANDLE,HANDLE,void **,ULONG_PTR,SIZE_T,LARGE_INTEGER *,SIZE_T *,ULONG,ULONG,ULONG);
typedef LONG (NTAPI *MapExFn)(HANDLE,HANDLE,void **,LARGE_INTEGER *,SIZE_T *,ULONG,ULONG,void *,ULONG);
typedef LONG (WINAPI *GdiFn)(void *);
static AllocFn origAlloc; static AllocExFn origAllocEx;
static MapFn origMap; static MapExFn origMapEx;
static GdiFn origCreate,origCreate2;
static GdiFn origLock2;
typedef struct {UINT device,allocation,flags;void *data;} Lock2;
typedef struct {UINT sType;void *next;UINT64 allocationSize;UINT memoryTypeIndex;} VkAllocInfo;
typedef LONG (WINAPI *VkAllocFn)(void *,const VkAllocInfo *,void *,UINT64 *);
static VkAllocFn origVkAlloc;
typedef struct { LONG ready; DWORD tid; int kind; LONG status; void *base; SIZE_T size; ULONG protect; USHORT count; void *stack[40]; } Event;
static Event events[8192];
static volatile LONG used;
static void record(int kind,LONG status,void *base,SIZE_T size,ULONG protect) {
    LONG i=InterlockedIncrement(&used)-1;
    if(i>=8192) return;
    Event *e=&events[i]; e->tid=GetCurrentThreadId();e->kind=kind;e->status=status;e->base=base;e->size=size;e->protect=protect;
    e->count=CaptureStackBackTrace(2,40,e->stack,NULL);
    InterlockedExchange(&e->ready,1);
}
static LONG NTAPI alloc(HANDLE p,void **b,ULONG_PTR z,SIZE_T *s,ULONG t,ULONG prot) {
    LONG r=origAlloc(p,b,z,s,t,prot);
    if(prot&PAGE_WRITECOMBINE) record(1,r,*b,*s,prot);
    return r;
}
static LONG NTAPI allocEx(HANDLE p,void **b,SIZE_T *s,ULONG t,ULONG prot,void *e,ULONG n) {
    LONG r=origAllocEx(p,b,s,t,prot,e,n);
    if(prot&PAGE_WRITECOMBINE) record(2,r,*b,*s,prot);
    return r;
}
static LONG NTAPI map(HANDLE sec,HANDLE p,void **b,ULONG_PTR z,SIZE_T c,LARGE_INTEGER *off,SIZE_T *s,ULONG inherit,ULONG t,ULONG prot) {
    LONG r=origMap(sec,p,b,z,c,off,s,inherit,t,prot);
    if(prot&PAGE_WRITECOMBINE) record(3,r,*b,*s,prot);
    return r;
}
static LONG NTAPI mapEx(HANDLE sec,HANDLE p,void **b,LARGE_INTEGER *off,SIZE_T *s,ULONG t,ULONG prot,void *e,ULONG n) {
    LONG r=origMapEx(sec,p,b,off,s,t,prot,e,n);
    if(prot&PAGE_WRITECOMBINE) record(4,r,*b,*s,prot);
    return r;
}
typedef struct {void *base;SIZE_T size;} Region;
static int wcRegions(Region *regions) {
    SIZE_T address=0;MEMORY_BASIC_INFORMATION m;int n=0;
    while(VirtualQuery((void *)address,&m,sizeof(m))) {
        if(m.State==MEM_COMMIT && (m.Protect&PAGE_WRITECOMBINE) && n<256) {
            regions[n].base=m.BaseAddress;regions[n].size=m.RegionSize;n++;
        }
        address=(SIZE_T)m.BaseAddress+m.RegionSize;
    }
    return n;
}
static LONG WINAPI create(void *arg) {
    Region before[256],after[256];int nb=wcRegions(before);
    LONG r=origCreate(arg);record(5,r,arg,0,0);
    int na=wcRegions(after);
    for(int i=0;i<na;i++) {
        SIZE_T cursor=(SIZE_T)after[i].base,end=cursor+after[i].size;
        for(int j=0;j<nb && cursor<end;j++) {
            SIZE_T b=(SIZE_T)before[j].base,e=b+before[j].size;
            if(e<=cursor || b>=end)continue;
            if(b>cursor)record(9,r,(void *)cursor,b-cursor,PAGE_READWRITE|PAGE_WRITECOMBINE);
            if(e>cursor)cursor=e;
        }
        if(cursor<end)record(9,r,(void *)cursor,end-cursor,PAGE_READWRITE|PAGE_WRITECOMBINE);
    }
    return r;
}
static LONG WINAPI create2(void *arg) {LONG r=origCreate2(arg);record(6,r,arg,0,0);return r;}
static LONG WINAPI lock2(void *arg) {
    LONG r=origLock2(arg);Lock2 *l=arg;
    if(r>=0 && l->data) {
        MEMORY_BASIC_INFORMATION mbi={0};VirtualQuery(l->data,&mbi,sizeof(mbi));
        record(8,r,l->data,mbi.RegionSize,mbi.Protect);
    }
    return r;
}
static LONG WINAPI vkalloc(void *device,const VkAllocInfo *info,void *cb,UINT64 *memory) {
    LONG r=origVkAlloc(device,info,cb,memory);
    record(7,r,(void *)*memory,info->allocationSize,info->memoryTypeIndex);
    return r;
}
static void hook(FILE *f,const wchar_t *dll,const char *name,void *fn,void **orig) {
    HMODULE m=GetModuleHandleW(dll); if(!m) {fprintf(f,"module missing %ls\n",dll);return;}
    void *target=(void *)GetProcAddress(m,name);
    MH_STATUS r=target?MH_CreateHook(target,fn,orig):MH_ERROR_FUNCTION_NOT_FOUND;
    fprintf(f,"hook %s=%s\n",name,MH_StatusToString(r));
}
__declspec(dllexport) DWORD WINAPI Start(void *path) {
    FILE *f=_wfopen(path,L"w"); if(!f) return 1;
    fprintf(f,"initialize=%s\n",MH_StatusToString(MH_Initialize()));
    hook(f,L"ntdll.dll","NtAllocateVirtualMemory",alloc,(void **)&origAlloc);
    hook(f,L"ntdll.dll","NtAllocateVirtualMemoryEx",allocEx,(void **)&origAllocEx);
    hook(f,L"ntdll.dll","NtMapViewOfSection",map,(void **)&origMap);
    hook(f,L"ntdll.dll","NtMapViewOfSectionEx",mapEx,(void **)&origMapEx);
    hook(f,L"win32u.dll","NtGdiDdDDICreateAllocation",create,(void **)&origCreate);
    hook(f,L"win32u.dll","NtGdiDdDDICreateAllocation2",create2,(void **)&origCreate2);
    hook(f,L"win32u.dll","NtGdiDdDDILock2",lock2,(void **)&origLock2);
    // Local diagnostic: this driver's allocation thunk was identified from
    // the previous call stack and its caller's VkMemoryAllocateInfo layout.
    HMODULE nv=GetModuleHandleW(L"nvoglv64.dll");
    if(nv) {
        void *vkTarget=(char *)nv+0xe1e500;
        fprintf(f,"vkAllocateMemory=%s\n",MH_StatusToString(MH_CreateHook(vkTarget,vkalloc,(void **)&origVkAlloc)));
    }
    fprintf(f,"enable=%s\n",MH_StatusToString(MH_EnableHook(MH_ALL_HOOKS)));
    fclose(f);return 0;
}
__declspec(dllexport) DWORD WINAPI Dump(void *path) {
    MH_DisableHook(MH_ALL_HOOKS);
    FILE *f=_wfopen(path,L"w");if(!f)return 1;
    SymSetOptions(SYMOPT_DEFERRED_LOADS|SYMOPT_UNDNAME|SYMOPT_LOAD_LINES);
    SymInitialize(GetCurrentProcess(),"C:\\Users\\Owner\\source\\repos\\lhat-love\\build\\love\\Release",TRUE);
    LONG n=used;if(n>8192)n=8192;
    fprintf(f,"events=%ld recorded=%ld\n",used,n);
    for(LONG i=0;i<n;i++) {
        Event *e=events+i;if(!e->ready)continue;
        fprintf(f,"EVENT %ld kind=%d status=%lx tid=%lu base=%p size=%zu protect=%lx\n",i,e->kind,e->status,e->tid,e->base,e->size,e->protect);
        for(USHORT j=0;j<e->count;j++) {
            char buf[sizeof(SYMBOL_INFO)+1024]={0}; SYMBOL_INFO *s=(SYMBOL_INFO *)buf;
            s->SizeOfStruct=sizeof(SYMBOL_INFO);s->MaxNameLen=1023;DWORD64 disp=0;
            MEMORY_BASIC_INFORMATION mbi={0};VirtualQuery(e->stack[j],&mbi,sizeof(mbi));
            wchar_t module[MAX_PATH]={0};GetModuleFileNameW(mbi.AllocationBase,module,MAX_PATH);
            const wchar_t *base=wcsrchr(module,L'\\');base=base?base+1:module;
            if(SymFromAddr(GetCurrentProcess(),(DWORD64)e->stack[j],&disp,s))
                fprintf(f,"  %p %ls+%llx %s+%llu\n",e->stack[j],base,(DWORD64)e->stack[j]-(DWORD64)mbi.AllocationBase,s->Name,disp);
            else fprintf(f,"  %p %ls+%llx\n",e->stack[j],base,(DWORD64)e->stack[j]-(DWORD64)mbi.AllocationBase);
        }
    }
    SymCleanup(GetCurrentProcess());fclose(f);return 0;
}
