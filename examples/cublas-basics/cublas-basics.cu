// cuBLAS is NVIDIA's GPU-accelerated BLAS (Basic Linear Algebra
// Subprograms) library. It provides highly optimized matrix and
// vector operations that are the building blocks of deep learning,
// scientific simulation, and HPC.
//
// Compile with: nvcc cublas-basics.cu -lcublas

#include <stdio.h>
#include <cublas_v2.h>

int main() {
    const int N = 4;
    const int NN = N * N;

    // cuBLAS uses column-major order (Fortran convention).
    // A = [1 2 3 4; 5 6 7 8; 9 10 11 12; 13 14 15 16] (row-major)
    // stored column-major: {1,5,9,13, 2,6,10,14, 3,7,11,15, 4,8,12,16}
    float h_A[NN], h_B[NN], h_C[NN];
    for (int i = 0; i < NN; i++) {
        h_A[i] = 1.0f;
        h_B[i] = 1.0f;
        h_C[i] = 0.0f;
    }

    float *d_A, *d_B, *d_C;
    cudaMalloc(&d_A, NN * sizeof(float));
    cudaMalloc(&d_B, NN * sizeof(float));
    cudaMalloc(&d_C, NN * sizeof(float));

    // Create a cuBLAS handle — one per application or thread.
    cublasHandle_t handle;
    cublasCreate(&handle);

    // Copy matrices to device using cuBLAS helper.
    cublasSetMatrix(N, N, sizeof(float), h_A, N, d_A, N);
    cublasSetMatrix(N, N, sizeof(float), h_B, N, d_B, N);

    // C = alpha * A * B + beta * C
    // SGEMM: Single-precision GEneral Matrix Multiply.
    float alpha = 1.0f, beta = 0.0f;
    cublasSgemm(handle,
                CUBLAS_OP_N, CUBLAS_OP_N,
                N, N, N,
                &alpha, d_A, N, d_B, N,
                &beta,  d_C, N);

    cublasGetMatrix(N, N, sizeof(float), d_C, N, h_C, N);

    // Each element should be N (dot product of N ones with N ones).
    printf("C[0]=%.0f, C[15]=%.0f (expected %d)\n", h_C[0], h_C[NN-1], N);

    cublasDestroy(handle);
    cudaFree(d_A); cudaFree(d_B); cudaFree(d_C);
    return 0;
}
