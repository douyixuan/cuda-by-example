// Memory coalescing is the single most important GPU performance concept.
// When consecutive threads access consecutive addresses, the hardware
// combines them into a single wide transaction. Scattered accesses
// waste bandwidth dramatically.

#include <stdio.h>

const int N = 1 << 20;

// Coalesced: thread i reads element i. Consecutive threads hit
// consecutive addresses → one 128-byte transaction per 32 threads.
__global__ void coalesced(const float *in, float *out, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) out[i] = in[i] * 2.0f;
}

// Strided: thread i reads element i*32. Threads in a warp hit
// addresses 32 elements apart → 32 separate transactions instead of 1.
__global__ void strided(const float *in, float *out, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int idx = (i * 32) % n;
    if (i < n) out[idx] = in[idx] * 2.0f;
}

int main() {
    float *d_in, *d_out;
    cudaMalloc(&d_in,  N * sizeof(float));
    cudaMalloc(&d_out, N * sizeof(float));

    int threads = 256;
    int blocks  = (N + threads - 1) / threads;

    // Time the coalesced version.
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);
    for (int i = 0; i < 100; i++)
        coalesced<<<blocks, threads>>>(d_in, d_out, N);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    float ms_coal = 0;
    cudaEventElapsedTime(&ms_coal, start, stop);

    // Time the strided (non-coalesced) version.
    cudaEventRecord(start);
    for (int i = 0; i < 100; i++)
        strided<<<blocks, threads>>>(d_in, d_out, N);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    float ms_stride = 0;
    cudaEventElapsedTime(&ms_stride, start, stop);

    printf("Coalesced: %.2f ms, Strided: %.2f ms (%.1fx slower)\n",
           ms_coal, ms_stride, ms_stride / ms_coal);

    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(d_in);
    cudaFree(d_out);
    return 0;
}
