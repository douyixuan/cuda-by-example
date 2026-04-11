// Shared memory is a small, fast scratchpad on each Streaming Multiprocessor.
// Threads within the same block can use it to cooperate and avoid
// redundant global memory reads.

#include <stdio.h>

const int BLOCK_SIZE = 256;

// This kernel computes a prefix sum (scan) within each block using
// shared memory. Each thread loads one element, then threads
// cooperate to accumulate partial sums.
__global__ void blockPrefixSum(const int *input, int *output, int n) {
    // `__shared__` allocates memory in the SM's shared memory bank.
    // All threads in this block see the same array.
    __shared__ int temp[BLOCK_SIZE];

    int tid = threadIdx.x;
    int gid = blockIdx.x * blockDim.x + tid;

    // Load from global memory into shared memory.
    temp[tid] = (gid < n) ? input[gid] : 0;

    // `__syncthreads()` is a barrier — all threads in the block
    // must reach this point before any can continue.
    // Required whenever threads read data written by other threads.
    __syncthreads();

    // Parallel prefix sum (Hillis-Steele scan).
    for (int stride = 1; stride < blockDim.x; stride *= 2) {
        int val = (tid >= stride) ? temp[tid - stride] : 0;
        __syncthreads();
        temp[tid] += val;
        __syncthreads();
    }

    if (gid < n) output[gid] = temp[tid];
}

int main() {
    const int N = BLOCK_SIZE;
    int h_in[N], h_out[N];
    for (int i = 0; i < N; i++) h_in[i] = 1;

    int *d_in, *d_out;
    cudaMalloc(&d_in,  N * sizeof(int));
    cudaMalloc(&d_out, N * sizeof(int));
    cudaMemcpy(d_in, h_in, N * sizeof(int), cudaMemcpyHostToDevice);

    blockPrefixSum<<<1, BLOCK_SIZE>>>(d_in, d_out, N);
    cudaMemcpy(h_out, d_out, N * sizeof(int), cudaMemcpyDeviceToHost);

    // With all-ones input, prefix sum at index i should be i+1.
    printf("h_out[0]=%d, h_out[127]=%d, h_out[255]=%d\n",
           h_out[0], h_out[127], h_out[255]);

    cudaFree(d_in);
    cudaFree(d_out);
    return 0;
}
