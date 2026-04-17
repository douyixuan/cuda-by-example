// Matrix multiplication is the "hello world" of GPU computing.
// This tiled implementation uses shared memory to reduce global
// memory traffic from O(N³) to O(N³/TILE), a critical optimization
// for compute-bound kernels.

#include <stdio.h>

const int N    = 512;
const int TILE = 16;

// Each thread computes one element of C. Threads in a block
// cooperatively load tiles of A and B into shared memory,
// reducing global memory reads by a factor of TILE.
__global__ void matmul(const float *A, const float *B, float *C, int n) {
    __shared__ float sA[TILE][TILE];
    __shared__ float sB[TILE][TILE];

    int row = blockIdx.y * TILE + threadIdx.y;
    int col = blockIdx.x * TILE + threadIdx.x;
    float sum = 0.0f;

    // Walk through tiles of A's row and B's column.
    for (int t = 0; t < n / TILE; t++) {
        sA[threadIdx.y][threadIdx.x] = A[row * n + t * TILE + threadIdx.x];
        sB[threadIdx.y][threadIdx.x] = B[(t * TILE + threadIdx.y) * n + col];
        __syncthreads();

        // Multiply the tile — all data is in fast shared memory.
        for (int k = 0; k < TILE; k++)
            sum += sA[threadIdx.y][k] * sB[k][threadIdx.x];
        __syncthreads();
    }

    C[row * n + col] = sum;
}

int main() {
    size_t bytes = N * N * sizeof(float);

    float *h_A = new float[N * N];
    float *h_B = new float[N * N];
    float *h_C = new float[N * N];

    for (int i = 0; i < N * N; i++) {
        h_A[i] = 1.0f;
        h_B[i] = 1.0f;
    }

    float *d_A, *d_B, *d_C;
    cudaMalloc(&d_A, bytes);
    cudaMalloc(&d_B, bytes);
    cudaMalloc(&d_C, bytes);
    cudaMemcpy(d_A, h_A, bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_B, h_B, bytes, cudaMemcpyHostToDevice);

    dim3 threads(TILE, TILE);
    dim3 blocks(N / TILE, N / TILE);
    matmul<<<blocks, threads>>>(d_A, d_B, d_C, N);
    cudaMemcpy(h_C, d_C, bytes, cudaMemcpyDeviceToHost);

    // Each element of C should be N (sum of N ones).
    printf("C[0][0]=%.0f, C[511][511]=%.0f (expected %d)\n",
           h_C[0], h_C[N*N-1], N);

    cudaFree(d_A); cudaFree(d_B); cudaFree(d_C);
    delete[] h_A; delete[] h_B; delete[] h_C;
    return 0;
}
