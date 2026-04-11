// Understanding how threads are indexed is fundamental to CUDA.
// Every thread has a unique identity built from three values:
// `threadIdx`, `blockIdx`, and `blockDim`.

#include <stdio.h>

// This kernel prints each thread's coordinates and its
// computed global index. Run it to see the pattern.
__global__ void showIndex() {
    // `threadIdx.x` is the thread's position within its block (0-based).
    // `blockIdx.x` is the block's position within the grid (0-based).
    // `blockDim.x` is the total number of threads per block.
    int globalIdx = blockIdx.x * blockDim.x + threadIdx.x;

    printf("block %d | thread %d | global %d\n",
           blockIdx.x, threadIdx.x, globalIdx);
}

int main() {
    // Launch 2 blocks of 4 threads each = 8 threads total.
    // Global indices will be 0..7.
    int blocks = 2;
    int threadsPerBlock = 4;
    showIndex<<<blocks, threadsPerBlock>>>();
    cudaDeviceSynchronize();

    // Note: the print order is non-deterministic. GPU threads
    // run in parallel and may complete in any order.
    // The global index formula is always deterministic though.
    return 0;
}
