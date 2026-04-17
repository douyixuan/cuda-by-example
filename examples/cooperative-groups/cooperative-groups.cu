// Cooperative Groups is a flexible API for organizing threads into
// groups that can synchronize and communicate. It replaces ad-hoc
// __syncthreads() with explicit, composable group abstractions.
//
// Compile with: nvcc -arch=sm_60 cooperative-groups.cu

#include <stdio.h>
#include <cooperative_groups.h>

namespace cg = cooperative_groups;

__global__ void reduceWithGroups(const int *input, int *output, int n) {
    // `this_thread_block()` gives a handle to the current block —
    // equivalent to using __syncthreads(), but as a first-class object.
    cg::thread_block block = cg::this_thread_block();

    extern __shared__ int sdata[];

    int tid = block.thread_rank();
    int gid = blockIdx.x * blockDim.x + tid;
    sdata[tid] = (gid < n) ? input[gid] : 0;

    block.sync();

    // Partition the block into tiles of 32 threads (warp-sized groups).
    // Each tile can synchronize independently of the rest of the block.
    cg::thread_block_tile<32> warp = cg::tiled_partition<32>(block);

    // Warp-level reduction using cooperative groups' `shfl_down`.
    int val = sdata[tid];
    for (int offset = warp.size() / 2; offset > 0; offset /= 2) {
        val += warp.shfl_down(val, offset);
    }

    // First thread in each warp writes partial sum to shared memory.
    if (warp.thread_rank() == 0)
        sdata[tid / 32] = val;

    block.sync();

    // First warp reduces the partial sums.
    if (tid < 32) {
        val = (tid < blockDim.x / 32) ? sdata[tid] : 0;
        cg::thread_block_tile<32> first_warp = cg::tiled_partition<32>(block);
        for (int offset = first_warp.size() / 2; offset > 0; offset /= 2)
            val += first_warp.shfl_down(val, offset);
        if (tid == 0) output[blockIdx.x] = val;
    }
}

int main() {
    const int N = 1024;
    int h_in[N], h_out;
    for (int i = 0; i < N; i++) h_in[i] = 1;

    int *d_in, *d_out;
    cudaMalloc(&d_in,  N * sizeof(int));
    cudaMalloc(&d_out, sizeof(int));
    cudaMemcpy(d_in, h_in, N * sizeof(int), cudaMemcpyHostToDevice);

    int threads = 256;
    int blocks  = (N + threads - 1) / threads;
    int smem    = threads * sizeof(int);
    reduceWithGroups<<<blocks, threads, smem>>>(d_in, d_out, N);

    // For simplicity, only the first block's result (256 ones → 256).
    cudaMemcpy(&h_out, d_out, sizeof(int), cudaMemcpyDeviceToHost);
    printf("Block 0 sum = %d (expected 256)\n", h_out);

    cudaFree(d_in);
    cudaFree(d_out);
    return 0;
}
