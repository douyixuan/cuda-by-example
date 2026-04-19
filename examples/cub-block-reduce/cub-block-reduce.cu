// CUB BlockReduce reduces all threads in a block to a single value.
// Unlike the manual parallel-reduction example, CUB manages shared
// memory allocation and the reduction tree automatically.
//
// Compile: nvcc -arch=sm_80 cub-block-reduce.cu -o cub-block-reduce

#include <cub/cub.cuh>
#include <stdio.h>

const int BLOCK = 256;

// Each block reduces its 256 values to one sum, written to output[blockIdx.x].
__global__ void blockSumKernel(const float *input, float *output, int n) {
    // BlockReduce requires shared temporary storage sized for the block.
    typedef cub::BlockReduce<float, BLOCK> BlockReduce;
    __shared__ typename BlockReduce::TempStorage temp;

    int gid = blockIdx.x * blockDim.x + threadIdx.x;
    float val = (gid < n) ? input[gid] : 0.0f;

    // All threads participate; result is valid only in thread 0.
    float block_sum = BlockReduce(temp).Sum(val);

    if (threadIdx.x == 0) {
        output[blockIdx.x] = block_sum;
    }
}

int main() {
    const int N = 1024;
    float h_in[N];
    for (int i = 0; i < N; i++) h_in[i] = 1.0f;

    int blocks = (N + BLOCK - 1) / BLOCK;
    float *d_in, *d_out;
    cudaMalloc(&d_in,  N * sizeof(float));
    cudaMalloc(&d_out, blocks * sizeof(float));
    cudaMemcpy(d_in, h_in, N * sizeof(float), cudaMemcpyHostToDevice);

    blockSumKernel<<<blocks, BLOCK>>>(d_in, d_out, N);

    float h_partial[4];
    cudaMemcpy(h_partial, d_out, blocks * sizeof(float), cudaMemcpyDeviceToHost);

    float total = 0;
    for (int i = 0; i < blocks; i++) total += h_partial[i];
    printf("Sum = %.0f (expected %d)\n", total, N);

    cudaFree(d_in);
    cudaFree(d_out);
    return 0;
}
