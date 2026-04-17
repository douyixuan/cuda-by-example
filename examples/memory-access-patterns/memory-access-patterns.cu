// This example compares four memory access patterns and their
// impact on bandwidth. The GPU's memory controller can coalesce
// sequential accesses into wide transactions, but random or
// misaligned patterns waste bandwidth dramatically.

#include <stdio.h>

const int N = 1 << 22;

// Pattern 1: Sequential — threads access consecutive elements.
// Fully coalesced: one 128-byte transaction per 32 threads.
__global__ void sequential(float *data, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) data[i] += 1.0f;
}

// Pattern 2: Strided — threads access every 2nd element.
// 50% bandwidth utilization: loads 128 bytes but uses only 64.
__global__ void strided2(float *data, int n) {
    int i = (blockIdx.x * blockDim.x + threadIdx.x) * 2;
    if (i < n) data[i] += 1.0f;
}

// Pattern 3: Strided by 32 — worst case for warps.
// Each thread hits a different cache line → 32 separate transactions.
__global__ void strided32(float *data, int n) {
    int i = (blockIdx.x * blockDim.x + threadIdx.x) * 32;
    if (i < n) data[i] += 1.0f;
}

// Pattern 4: Offset by 1 — misaligned but still nearly coalesced.
// Crosses a cache line boundary but most GPUs handle this well.
__global__ void offset1(float *data, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x + 1;
    if (i < n) data[i] += 1.0f;
}

float benchmark(void (*kernel)(float*, int), float *d_data, int n) {
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    int threads = 256;
    int blocks  = (n + threads - 1) / threads;

    cudaEventRecord(start);
    for (int r = 0; r < 100; r++)
        kernel<<<blocks, threads>>>(d_data, n);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float ms = 0;
    cudaEventElapsedTime(&ms, start, stop);
    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    return ms;
}

int main() {
    float *d_data;
    cudaMalloc(&d_data, N * sizeof(float));

    printf("Sequential:  %.2f ms\n", benchmark(sequential, d_data, N));
    printf("Stride-2:    %.2f ms\n", benchmark(strided2, d_data, N));
    printf("Stride-32:   %.2f ms\n", benchmark(strided32, d_data, N));
    printf("Offset-1:    %.2f ms\n", benchmark(offset1, d_data, N));

    cudaFree(d_data);
    return 0;
}
