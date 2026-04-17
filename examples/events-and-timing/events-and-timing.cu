// CUDA events provide precise GPU-side timing. Unlike CPU timers,
// events measure actual GPU execution time without including
// launch overhead or CPU-GPU synchronization delays.

#include <stdio.h>

const int N = 1 << 22;

__global__ void saxpy(float a, const float *x, float *y, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) y[i] = a * x[i] + y[i];
}

int main() {
    float *d_x, *d_y;
    cudaMalloc(&d_x, N * sizeof(float));
    cudaMalloc(&d_y, N * sizeof(float));

    // Create events for timing. Events record timestamps in the
    // GPU's own clock — no CPU involvement.
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    int threads = 256;
    int blocks  = (N + threads - 1) / threads;

    // Record the start event into the default stream.
    // This inserts a timestamp marker in the GPU's command queue.
    cudaEventRecord(start);

    saxpy<<<blocks, threads>>>(2.0f, d_x, d_y, N);

    // Record the stop event — it will fire after the kernel completes.
    cudaEventRecord(stop);

    // Wait for the stop event to complete before reading the time.
    cudaEventSynchronize(stop);

    // Compute elapsed time in milliseconds.
    float ms = 0;
    cudaEventElapsedTime(&ms, start, stop);

    float gb = 3.0f * N * sizeof(float) / 1e9;
    printf("SAXPY: %.3f ms  (%.1f GB/s)\n", ms, gb / (ms / 1000.0f));

    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(d_x);
    cudaFree(d_y);
    return 0;
}
