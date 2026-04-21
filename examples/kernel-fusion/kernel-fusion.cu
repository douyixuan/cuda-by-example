// Kernel fusion combines multiple operations into a single kernel,
// eliminating intermediate global memory round-trips. Here, bias add
// and ReLU activation are fused: one read, one write instead of two.
// This pattern is ubiquitous in LLM inference (fused bias+GELU, etc.).
//
// Source: [github.com/NVIDIA/Megatron-LM](https://github.com/NVIDIA/Megatron-LM/blob/main/megatron/core/fusions) — fusions/
// Compile: nvcc -arch=sm_80 kernel-fusion.cu -o kernel-fusion

#include <stdio.h>
#include <math.h>

const int N = 1024;

// Unfused: two separate kernels, two global memory passes.
__global__ void addBias(float *x, const float *bias, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) x[i] += bias[i % 64];
}
__global__ void applyRelu(float *x, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) x[i] = fmaxf(0.0f, x[i]);
}

// Fused: bias add + ReLU in one kernel, one global memory pass.
__global__ void fusedBiasRelu(float *x, const float *bias, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) x[i] = fmaxf(0.0f, x[i] + bias[i % 64]);
}

int main() {
    float h_x[N], h_bias[64], h_fused[N];
    for (int i = 0; i < N; i++)    h_x[i]    = (i % 3 == 0) ? -1.0f : 1.0f;
    for (int i = 0; i < 64; i++)   h_bias[i]  = 0.5f;

    float *d_x, *d_bias;
    cudaMalloc(&d_x,    N  * sizeof(float));
    cudaMalloc(&d_bias, 64 * sizeof(float));
    cudaMemcpy(d_bias, h_bias, 64 * sizeof(float), cudaMemcpyHostToDevice);

    // Unfused path.
    cudaMemcpy(d_x, h_x, N * sizeof(float), cudaMemcpyHostToDevice);
    addBias<<<4, 256>>>(d_x, d_bias, N);
    applyRelu<<<4, 256>>>(d_x, N);
    float h_unfused[N];
    cudaMemcpy(h_unfused, d_x, N * sizeof(float), cudaMemcpyDeviceToHost);

    // Fused path.
    cudaMemcpy(d_x, h_x, N * sizeof(float), cudaMemcpyHostToDevice);
    fusedBiasRelu<<<4, 256>>>(d_x, d_bias, N);
    cudaMemcpy(h_fused, d_x, N * sizeof(float), cudaMemcpyDeviceToHost);

    // Both paths should produce identical results.
    int match = 1;
    for (int i = 0; i < N; i++) if (h_unfused[i] != h_fused[i]) { match = 0; break; }
    printf("Unfused[0]=%.1f  Fused[0]=%.1f  Match=%s\n",
           h_unfused[0], h_fused[0], match ? "yes" : "no");

    cudaFree(d_x); cudaFree(d_bias);
    return 0;
}
