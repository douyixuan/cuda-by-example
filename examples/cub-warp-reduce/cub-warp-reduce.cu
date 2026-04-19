// CUB WarpReduce performs a reduction across all 32 threads in a warp
// using hardware shuffle instructions — no shared memory required.
// Compare with warp-primitives, which implements this manually.
//
// Compile: nvcc -arch=sm_80 cub-warp-reduce.cu -o cub-warp-reduce

#include <cub/cub.cuh>
#include <stdio.h>

// Each block has 64 threads (2 warps). Each warp independently reduces
// its 32 values to a single sum using CUB's WarpReduce primitive.
__global__ void warpSumKernel(const float *input, float *output, int n) {
    // WarpReduce requires a per-warp temporary storage object.
    // Declaring it __shared__ ensures each warp gets its own instance.
    typedef cub::WarpReduce<float> WarpReduce;
    __shared__ typename WarpReduce::TempStorage temp[2];

    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    int warp_id = threadIdx.x / 32;

    float val = (tid < n) ? input[tid] : 0.0f;

    // Sum all 32 values in this warp. Result lands in lane 0.
    float warp_sum = WarpReduce(temp[warp_id]).Sum(val);

    // Lane 0 of each warp writes the partial sum.
    if (threadIdx.x % 32 == 0) {
        atomicAdd(output, warp_sum);
    }
}

int main() {
    const int N = 64;
    float h_in[N], h_out = 0.0f;
    for (int i = 0; i < N; i++) h_in[i] = 1.0f;

    float *d_in, *d_out;
    cudaMalloc(&d_in,  N * sizeof(float));
    cudaMalloc(&d_out, sizeof(float));
    cudaMemcpy(d_in,  h_in,   N * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(d_out, &h_out, sizeof(float),     cudaMemcpyHostToDevice);

    warpSumKernel<<<1, N>>>(d_in, d_out, N);
    cudaMemcpy(&h_out, d_out, sizeof(float), cudaMemcpyDeviceToHost);

    printf("Sum = %.0f (expected %d)\n", h_out, N);

    cudaFree(d_in);
    cudaFree(d_out);
    return 0;
}
