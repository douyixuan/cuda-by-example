// Shared memory is divided into 32 banks. When two threads in a warp
// access the same bank (but different addresses), they serialize —
// a "bank conflict." Adding padding to shared memory arrays is the
// classic fix: it shifts columns so consecutive threads hit different banks.

#include <stdio.h>

const int TILE = 32;

// WITHOUT padding: column access causes 32-way bank conflicts.
// Bank = address % 32, so column j of a 32-wide array always
// hits bank j regardless of row — all threads in a warp collide.
__global__ void transposeConflict(const float *in, float *out, int n) {
    __shared__ float tile[TILE][TILE];

    int x = blockIdx.x * TILE + threadIdx.x;
    int y = blockIdx.y * TILE + threadIdx.y;
    tile[threadIdx.y][threadIdx.x] = in[y * n + x];
    __syncthreads();

    x = blockIdx.y * TILE + threadIdx.x;
    y = blockIdx.x * TILE + threadIdx.y;
    out[y * n + x] = tile[threadIdx.x][threadIdx.y];
}

// WITH padding (+1): shifts each row by one bank, so column access
// spreads across all 32 banks. Zero bank conflicts.
__global__ void transposePadded(const float *in, float *out, int n) {
    __shared__ float tile[TILE][TILE + 1];

    int x = blockIdx.x * TILE + threadIdx.x;
    int y = blockIdx.y * TILE + threadIdx.y;
    tile[threadIdx.y][threadIdx.x] = in[y * n + x];
    __syncthreads();

    x = blockIdx.y * TILE + threadIdx.x;
    y = blockIdx.x * TILE + threadIdx.y;
    out[y * n + x] = tile[threadIdx.x][threadIdx.y];
}

int main() {
    const int N = 1024;
    size_t bytes = N * N * sizeof(float);
    float *d_in, *d_out;
    cudaMalloc(&d_in, bytes);
    cudaMalloc(&d_out, bytes);

    dim3 threads(TILE, TILE);
    dim3 blocks(N / TILE, N / TILE);

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);
    for (int i = 0; i < 100; i++)
        transposeConflict<<<blocks, threads>>>(d_in, d_out, N);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    float ms_conflict = 0;
    cudaEventElapsedTime(&ms_conflict, start, stop);

    cudaEventRecord(start);
    for (int i = 0; i < 100; i++)
        transposePadded<<<blocks, threads>>>(d_in, d_out, N);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    float ms_padded = 0;
    cudaEventElapsedTime(&ms_padded, start, stop);

    printf("With conflicts: %.2f ms, Padded: %.2f ms (%.1fx speedup)\n",
           ms_conflict, ms_padded, ms_conflict / ms_padded);

    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(d_in);
    cudaFree(d_out);
    return 0;
}
