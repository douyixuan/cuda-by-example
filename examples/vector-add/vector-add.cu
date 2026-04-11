// Vector addition is the "hello world" of GPU computing.
// We add two arrays element-wise: C[i] = A[i] + B[i].
// Each GPU thread handles one element independently.

#include <stdio.h>
#include <stdlib.h>

const int N = 1024;

// Each thread computes one output element.
// `blockIdx.x` is the block's index in the grid.
// `blockDim.x` is the number of threads per block.
// `threadIdx.x` is the thread's index within its block.
// Together they give a unique global index for each thread.
__global__ void vectorAdd(const float *A, const float *B, float *C, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        C[i] = A[i] + B[i];
    }
}

int main() {
    size_t size = N * sizeof(float);

    // Allocate and initialize host (CPU) arrays.
    float *h_A = (float *)malloc(size);
    float *h_B = (float *)malloc(size);
    float *h_C = (float *)malloc(size);
    for (int i = 0; i < N; i++) {
        h_A[i] = (float)i;
        h_B[i] = (float)(N - i);
    }

    // `cudaMalloc` allocates memory on the GPU (device).
    // Device pointers can only be dereferenced inside kernels.
    float *d_A, *d_B, *d_C;
    cudaMalloc(&d_A, size);
    cudaMalloc(&d_B, size);
    cudaMalloc(&d_C, size);

    // Copy data from host to device before the kernel runs.
    cudaMemcpy(d_A, h_A, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_B, h_B, size, cudaMemcpyHostToDevice);

    // Launch configuration: 256 threads per block,
    // enough blocks to cover all N elements.
    int threadsPerBlock = 256;
    int blocksPerGrid = (N + threadsPerBlock - 1) / threadsPerBlock;
    vectorAdd<<<blocksPerGrid, threadsPerBlock>>>(d_A, d_B, d_C, N);

    // Copy results back to the host after the kernel finishes.
    cudaMemcpy(h_C, d_C, size, cudaMemcpyDeviceToHost);

    // Verify: every element should equal N (1024).
    for (int i = 0; i < N; i++) {
        if (h_C[i] != (float)N) {
            printf("Mismatch at %d: %f\n", i, h_C[i]);
            return 1;
        }
    }
    printf("Vector addition correct. C[0]=%g, C[%d]=%g\n",
           h_C[0], N-1, h_C[N-1]);

    // Always free device memory when done.
    cudaFree(d_A);
    cudaFree(d_B);
    cudaFree(d_C);
    free(h_A);
    free(h_B);
    free(h_C);
    return 0;
}
