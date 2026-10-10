#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>

typedef struct { HANDLE heap; SIZE_T busy, free, committed, reserved, largest, count; DWORD error; } Row;
__declspec(dllexport) DWORD WINAPI Snapshot(void *path) {
    HANDLE heaps[256];
    Row rows[256] = {0};
    DWORD count = GetProcessHeaps(256, heaps);
    if (count > 256) return 1;
    for (DWORD i = 0; i < count; ++i) {
        Row *r = rows + i;
        r->heap = heaps[i];
        if (!HeapLock(heaps[i])) { r->error = GetLastError(); continue; }
        PROCESS_HEAP_ENTRY e = {0};
        while (HeapWalk(heaps[i], &e)) {
            if (e.wFlags & PROCESS_HEAP_ENTRY_BUSY) {
                r->busy += e.cbData; r->count++;
                if (e.cbData > r->largest) r->largest = e.cbData;
            } else if (e.wFlags & PROCESS_HEAP_REGION) {
                r->committed += e.Region.dwCommittedSize;
                r->reserved += e.Region.dwUnCommittedSize;
            } else if (!(e.wFlags & PROCESS_HEAP_UNCOMMITTED_RANGE)) r->free += e.cbData;
        }
        r->error = GetLastError();
        HeapUnlock(heaps[i]);
    }
    FILE *f = _wfopen((const wchar_t *)path, L"w");
    if (!f) return 2;
    fprintf(f, "heap,busy,free,committed,uncommitted,largest,blocks,error\n");
    for (DWORD i = 0; i < count; ++i) {
        Row *r = rows + i;
        fprintf(f, "%p,%zu,%zu,%zu,%zu,%zu,%zu,%lu\n", r->heap, r->busy, r->free, r->committed, r->reserved, r->largest, r->count, r->error);
    }
    fclose(f);
    return 0;
}
