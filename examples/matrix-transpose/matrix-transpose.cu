// Matrix transpose seems trivial but is a classic GPU optimization
// puzzle. A naive transpose causes uncoalesced writes (stride-N
// access). Using shared memory as a staging area converts the
// problem into coalesced reads AND coalesced writes.

#include <stdio.h>

const int N    = 1024;
const int TILE = 32;

// Naive transpose: coalesced reads from `in`, but strided writes
// to `out` (column-major pattern). Wastes memory bandwidth.
__global__ void transposeNaive(const float *in, float *out, int n) {
    int x = blockIdx.x * TILE + threadIdx.x;
    int y = blockIdx.y * TILE + threadIdx.y;
    if (x < n && y < n)
        out[x * n + y] = in[y * n + x];
}

// Optimized: load a tile into shared memory (coalesced read),
// then write from shared memory (coalesced write).
// The +1 padding avoids bank conflicts on shared memory.
__global__ void transposeShared(const float *in, float *out, int n) {
    __shared__ float tile[TILE][TILE + 1];

    int xIn = blockIdx.x * TILE + threadIdx.x;
    int yIn = blockIdx.y * TILE + threadIdx.y;

    if (xIn < n && yIn < n)
        tile[threadIdx.y][threadIdx.x] = in[yIn * n + xIn];
    __syncthreads();

    int xOut = blockIdx.y * TILE + threadIdx.x;
    int yOut = blockIdx.x * TILE + threadIdx.y;
    if (xOut < n && yOut < n)
        out[yOut * n + xOut] = tile[threadIdx.x][threadIdx.y];
}

int main() {
    size_t bytes = N * N * sizeof(float);
    float *d_in, *d_out;
    cudaMalloc(&d_in,  bytes);
    cudaMalloc(&d_out, bytes);

    dim3 threads(TILE, TILE);
    dim3 blocks(N / TILE, N / TILE);

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    // Time naive version.
    cudaEventRecord(start);
    for (int i = 0; i < 100; i++)
        transposeNaive<<<blocks, threads>>>(d_in, d_out, N);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    float ms_naive = 0;
    cudaEventElapsedTime(&ms_naive, start, stop);

    // Time shared-memory version.
    cudaEventRecord(start);
    for (int i = 0; i < 100; i++)
        transposeShared<<<blocks, threads>>>(d_in, d_out, N);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    float ms_shared = 0;
    cudaEventElapsedTime(&ms_shared, start, stop);

    printf("Naive: %.2f ms, Shared: %.2f ms (%.1fx speedup)\n",
           ms_naive, ms_shared, ms_naive / ms_shared);

    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(d_in);
    cudaFree(d_out);
    return 0;
}
