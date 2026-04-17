// Loop unrolling reduces branch overhead and enables the compiler
// to schedule independent instructions. `#pragma unroll` tells nvcc
// to replicate the loop body N times, trading code size for speed.

#include <stdio.h>

const int N = 1 << 20;

// Without unrolling: the loop runs 4 iterations with branch checks.
__global__ void noUnroll(const float *in, float *out, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        float val = in[i];
        for (int j = 0; j < 4; j++)
            val = val * val + 0.1f;
        out[i] = val;
    }
}

// With unrolling: the compiler duplicates the loop body, removing
// the loop counter and branch. Instructions can be pipelined better.
__global__ void withUnroll(const float *in, float *out, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        float val = in[i];
        #pragma unroll
        for (int j = 0; j < 4; j++)
            val = val * val + 0.1f;
        out[i] = val;
    }
}

int main() {
    float *d_in, *d_out;
    cudaMalloc(&d_in,  N * sizeof(float));
    cudaMalloc(&d_out, N * sizeof(float));

    int threads = 256;
    int blocks  = (N + threads - 1) / threads;

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);
    for (int i = 0; i < 100; i++)
        noUnroll<<<blocks, threads>>>(d_in, d_out, N);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    float ms_no = 0;
    cudaEventElapsedTime(&ms_no, start, stop);

    cudaEventRecord(start);
    for (int i = 0; i < 100; i++)
        withUnroll<<<blocks, threads>>>(d_in, d_out, N);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    float ms_yes = 0;
    cudaEventElapsedTime(&ms_yes, start, stop);

    printf("No unroll: %.2f ms, Unrolled: %.2f ms\n", ms_no, ms_yes);

    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(d_in);
    cudaFree(d_out);
    return 0;
}
