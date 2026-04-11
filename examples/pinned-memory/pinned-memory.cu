// Pinned memory (page-locked) is host memory that the OS guarantees
// will never be swapped to disk. This lets the GPU DMA engine transfer
// data directly, bypassing the CPU — significantly faster than
// pageable memory for large transfers.

#include <stdio.h>
#include <time.h>

const int N = 1 << 24; // 16M floats = 64 MB

double now_ms() {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1e3 + t.tv_nsec * 1e-6;
}

int main() {
    size_t bytes = N * sizeof(float);
    float *d_data;
    cudaMalloc(&d_data, bytes);

    // --- Pageable memory (regular malloc) ---
    float *h_pageable = (float *)malloc(bytes);
    for (int i = 0; i < N; i++) h_pageable[i] = (float)i;

    double t0 = now_ms();
    cudaMemcpy(d_data, h_pageable, bytes, cudaMemcpyHostToDevice);
    cudaDeviceSynchronize();
    double pageable_ms = now_ms() - t0;

    // --- Pinned memory (cudaMallocHost) ---
    // `cudaMallocHost` allocates page-locked memory. The GPU can
    // access it directly via DMA without staging through a temp buffer.
    float *h_pinned;
    cudaMallocHost(&h_pinned, bytes);
    for (int i = 0; i < N; i++) h_pinned[i] = (float)i;

    t0 = now_ms();
    cudaMemcpy(d_data, h_pinned, bytes, cudaMemcpyHostToDevice);
    cudaDeviceSynchronize();
    double pinned_ms = now_ms() - t0;

    printf("Pageable H→D: %.2f ms\n", pageable_ms);
    printf("Pinned   H→D: %.2f ms\n", pinned_ms);
    printf("Speedup: %.1fx\n", pageable_ms / pinned_ms);

    // Always free pinned memory with cudaFreeHost, not free().
    free(h_pageable);
    cudaFreeHost(h_pinned);
    cudaFree(d_data);
    return 0;
}
