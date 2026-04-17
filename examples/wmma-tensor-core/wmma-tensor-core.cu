// WMMA (Warp Matrix Multiply-Accumulate) is the programming interface
// for Tensor Cores — specialized hardware that computes D = A*B + C
// on 16×16 matrices in a single warp operation. Tensor Cores deliver
// 8-16x throughput vs. regular CUDA cores for matrix math.
//
// Compile with: nvcc -arch=sm_70 wmma-tensor-core.cu
// Requires: Volta (V100) or newer GPU with Tensor Cores.

#include <stdio.h>
#include <mma.h>

using namespace nvcuda;

const int M = 16;
const int N = 16;
const int K = 16;

// One warp computes a 16×16 output tile using Tensor Cores.
// Inputs are half-precision (FP16), accumulation is FP32.
__global__ void wmmaMatmul(const half *A, const half *B, float *C) {
    // Declare matrix fragments — these map to Tensor Core registers.
    // `matrix_a` and `matrix_b` hold FP16 input tiles.
    // `accumulator` holds the FP32 result.
    wmma::fragment<wmma::matrix_a, M, N, K, half, wmma::row_major> a_frag;
    wmma::fragment<wmma::matrix_b, M, N, K, half, wmma::row_major> b_frag;
    wmma::fragment<wmma::accumulator, M, N, K, float> c_frag;

    // Initialize accumulator to zero.
    wmma::fill_fragment(c_frag, 0.0f);

    // Load 16×16 tiles from global memory into fragments.
    wmma::load_matrix_sync(a_frag, A, K);
    wmma::load_matrix_sync(b_frag, B, N);

    // D = A * B + C — executed on Tensor Cores in one warp instruction.
    // This single call replaces 16×16×16 = 4096 multiply-adds.
    wmma::mma_sync(c_frag, a_frag, b_frag, c_frag);

    // Store the result back to global memory.
    wmma::store_matrix_sync(C, c_frag, N, wmma::mem_row_major);
}

int main() {
    // Allocate FP16 inputs and FP32 output.
    half h_A[M * K], h_B[K * N];
    float h_C[M * N];

    for (int i = 0; i < M * K; i++) h_A[i] = __float2half(1.0f);
    for (int i = 0; i < K * N; i++) h_B[i] = __float2half(1.0f);

    half *d_A, *d_B;
    float *d_C;
    cudaMalloc(&d_A, M * K * sizeof(half));
    cudaMalloc(&d_B, K * N * sizeof(half));
    cudaMalloc(&d_C, M * N * sizeof(float));
    cudaMemcpy(d_A, h_A, M * K * sizeof(half), cudaMemcpyHostToDevice);
    cudaMemcpy(d_B, h_B, K * N * sizeof(half), cudaMemcpyHostToDevice);

    // Launch with exactly one warp (32 threads).
    // WMMA operations are warp-cooperative — all 32 threads participate.
    wmmaMatmul<<<1, 32>>>(d_A, d_B, d_C);
    cudaMemcpy(h_C, d_C, M * N * sizeof(float), cudaMemcpyDeviceToHost);

    // Each element should be K=16 (sum of 16 ones).
    printf("C[0][0]=%.0f, C[15][15]=%.0f (expected %d)\n",
           h_C[0], h_C[M*N-1], K);

    cudaFree(d_A); cudaFree(d_B); cudaFree(d_C);
    return 0;
}
