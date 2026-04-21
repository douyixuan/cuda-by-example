// cuBLAS Batched GEMM computes multiple independent matrix multiplications
// in a single call. Transformers use this for multi-head attention: each
// head is a separate GEMM, and batching them avoids kernel launch overhead.
//
// Source: [github.com/NVIDIA/CUDALibrarySamples](https://github.com/NVIDIA/CUDALibrarySamples/tree/master/cuBLAS) — cuBLAS/
// Compile: nvcc cublas-batched-gemm.cu -lcublas -o cublas-batched-gemm

#include <stdio.h>
#include <cublas_v2.h>

int main() {
    const int BATCH = 4;  // number of heads
    const int M = 8, N = 8, K = 8;
    const int NN = M * N;

    float h_A[BATCH][NN], h_B[BATCH][NN], h_C[BATCH][NN];
    for (int b = 0; b < BATCH; b++)
        for (int i = 0; i < NN; i++) { h_A[b][i] = 1.0f; h_B[b][i] = 1.0f; h_C[b][i] = 0.0f; }

    float *d_A[BATCH], *d_B[BATCH], *d_C[BATCH];
    for (int b = 0; b < BATCH; b++) {
        cudaMalloc(&d_A[b], NN * sizeof(float));
        cudaMalloc(&d_B[b], NN * sizeof(float));
        cudaMalloc(&d_C[b], NN * sizeof(float));
        cudaMemcpy(d_A[b], h_A[b], NN * sizeof(float), cudaMemcpyHostToDevice);
        cudaMemcpy(d_B[b], h_B[b], NN * sizeof(float), cudaMemcpyHostToDevice);
        cudaMemcpy(d_C[b], h_C[b], NN * sizeof(float), cudaMemcpyHostToDevice);
    }

    // Build device-side pointer arrays for the batched call.
    float **d_Aarray, **d_Barray, **d_Carray;
    cudaMalloc(&d_Aarray, BATCH * sizeof(float *));
    cudaMalloc(&d_Barray, BATCH * sizeof(float *));
    cudaMalloc(&d_Carray, BATCH * sizeof(float *));
    cudaMemcpy(d_Aarray, d_A, BATCH * sizeof(float *), cudaMemcpyHostToDevice);
    cudaMemcpy(d_Barray, d_B, BATCH * sizeof(float *), cudaMemcpyHostToDevice);
    cudaMemcpy(d_Carray, d_C, BATCH * sizeof(float *), cudaMemcpyHostToDevice);

    cublasHandle_t handle;
    cublasCreate(&handle);

    float alpha = 1.0f, beta = 0.0f;
    // C[b] = alpha * A[b] * B[b] + beta * C[b]  for each b in [0, BATCH).
    cublasSgemmBatched(handle,
        CUBLAS_OP_N, CUBLAS_OP_N,
        M, N, K,
        &alpha, (const float **)d_Aarray, M,
                (const float **)d_Barray, K,
        &beta,  d_Carray, M,
        BATCH);

    cudaMemcpy(h_C[0], d_C[0], NN * sizeof(float), cudaMemcpyDeviceToHost);
    // Each element should be K=8 (dot product of K ones).
    printf("Batch 0: C[0]=%.0f, C[63]=%.0f (expected %d)\n", h_C[0][0], h_C[0][NN-1], K);

    cublasDestroy(handle);
    for (int b = 0; b < BATCH; b++) { cudaFree(d_A[b]); cudaFree(d_B[b]); cudaFree(d_C[b]); }
    cudaFree(d_Aarray); cudaFree(d_Barray); cudaFree(d_Carray);
    return 0;
}
