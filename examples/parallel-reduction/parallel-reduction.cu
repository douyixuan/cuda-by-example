// Parallel reduction computes a single value (sum, max, min) from
// an array using the GPU. Each step halves the active threads,
// combining pairs until one result remains. This tree-based approach
// turns an O(n) serial operation into O(log n) parallel steps.

#include <stdio.h>

const int N = 1024;
const int BLOCK = 256;

// Each block reduces its portion to a single value in shared memory.
__global__ void reduce(const float *input, float *output, int n) {
    extern __shared__ float sdata[];

    int tid = threadIdx.x;
    int gid = blockIdx.x * blockDim.x + tid;

    sdata[tid] = (gid < n) ? input[gid] : 0.0f;
    __syncthreads();

    // Tree reduction: stride starts at half the block, halves each step.
    // Threads with tid < stride add the element at tid+stride.
    for (int stride = blockDim.x / 2; stride > 0; stride >>= 1) {
        if (tid < stride)
            sdata[tid] += sdata[tid + stride];
        __syncthreads();
    }

    // Thread 0 of each block writes the block's partial sum.
    if (tid == 0) output[blockIdx.x] = sdata[0];
}

int main() {
    float h_in[N];
    for (int i = 0; i < N; i++) h_in[i] = 1.0f;

    float *d_in, *d_out;
    int blocks = (N + BLOCK - 1) / BLOCK;
    cudaMalloc(&d_in,  N * sizeof(float));
    cudaMalloc(&d_out, blocks * sizeof(float));
    cudaMemcpy(d_in, h_in, N * sizeof(float), cudaMemcpyHostToDevice);

    reduce<<<blocks, BLOCK, BLOCK * sizeof(float)>>>(d_in, d_out, N);

    // Copy partial sums back and finish on CPU.
    float h_partial[16];
    cudaMemcpy(h_partial, d_out, blocks * sizeof(float), cudaMemcpyDeviceToHost);

    float total = 0;
    for (int i = 0; i < blocks; i++) total += h_partial[i];
    printf("Sum = %.0f (expected %d)\n", total, N);

    cudaFree(d_in);
    cudaFree(d_out);
    return 0;
}
