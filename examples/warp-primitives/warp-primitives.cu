// Warp shuffle instructions let threads exchange values directly
// within a warp (32 threads) without going through shared memory.
// They're faster and use no shared memory bandwidth.

#include <stdio.h>

// Compute the sum of all values in a warp using shuffle-down reduction.
// Each step halves the active threads, passing values "down" the warp.
__device__ float warpReduceSum(float val) {
    // `__shfl_down_sync` shifts values from higher-indexed lanes to
    // lower-indexed lanes. The mask 0xffffffff means all 32 lanes participate.
    for (int offset = 16; offset > 0; offset >>= 1) {
        val += __shfl_down_sync(0xffffffff, val, offset);
    }
    // After the loop, lane 0 holds the sum of all 32 lanes.
    return val;
}

__global__ void sumKernel(const float *input, float *output, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    float val = (i < n) ? input[i] : 0.0f;

    // Reduce within the warp.
    val = warpReduceSum(val);

    // Lane 0 of each warp writes the partial sum.
    // `threadIdx.x % 32 == 0` identifies lane 0 of each warp.
    if (threadIdx.x % 32 == 0) {
        atomicAdd(output, val);
    }
}

int main() {
    const int N = 1024;
    float h_in[N], h_out = 0.0f;
    for (int i = 0; i < N; i++) h_in[i] = 1.0f;

    float *d_in, *d_out;
    cudaMalloc(&d_in,  N * sizeof(float));
    cudaMalloc(&d_out, sizeof(float));
    cudaMemcpy(d_in,  h_in,   N * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(d_out, &h_out, sizeof(float),     cudaMemcpyHostToDevice);

    sumKernel<<<4, 256>>>(d_in, d_out, N);
    cudaMemcpy(&h_out, d_out, sizeof(float), cudaMemcpyDeviceToHost);

    printf("Sum = %.0f (expected %d)\n", h_out, N);

    cudaFree(d_in);
    cudaFree(d_out);
    return 0;
}
