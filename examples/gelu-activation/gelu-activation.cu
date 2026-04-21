// GELU (Gaussian Error Linear Unit) is the activation function used in
// GPT-2, BERT, and most modern transformers. The tanh approximation
// avoids the slower erf() call and is accurate to within 0.0001.
// Fusing bias add with GELU saves one global memory round-trip.
//
// Source: [github.com/NVIDIA/Megatron-LM](https://github.com/NVIDIA/Megatron-LM/blob/main/megatron/core/fusions/fused_bias_gelu.py) — bias\_gelu\_fusion
// Compile: nvcc -arch=sm_80 gelu-activation.cu -o gelu-activation

#include <stdio.h>
#include <math.h>

const int N = 1024;

// GELU(x) ≈ 0.5 * x * (1 + tanh(sqrt(2/π) * (x + 0.044715 * x³)))
__device__ float gelu(float x) {
    const float k = 0.7978845608f;  // sqrt(2/pi)
    return 0.5f * x * (1.0f + tanhf(k * (x + 0.044715f * x * x * x)));
}

// Fused bias + GELU: one kernel, one global memory pass.
__global__ void fusedBiasGelu(float *x, const float *bias, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) x[i] = gelu(x[i] + bias[i % 64]);
}

int main() {
    float h_x[N], h_bias[64];
    for (int i = 0; i < N;  i++) h_x[i]    = (float)(i - N/2) / (N/2);
    for (int i = 0; i < 64; i++) h_bias[i]  = 0.0f;

    float *d_x, *d_bias;
    cudaMalloc(&d_x,    N  * sizeof(float));
    cudaMalloc(&d_bias, 64 * sizeof(float));
    cudaMemcpy(d_x,    h_x,    N  * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(d_bias, h_bias, 64 * sizeof(float), cudaMemcpyHostToDevice);

    fusedBiasGelu<<<4, 256>>>(d_x, d_bias, N);
    cudaMemcpy(h_x, d_x, N * sizeof(float), cudaMemcpyDeviceToHost);

    // GELU(-1)≈-0.1588, GELU(0)=0, GELU(1)≈0.8413
    printf("GELU(-1)=%.4f  GELU(0)=%.4f  GELU(1)=%.4f\n",
           h_x[0], h_x[N/2], h_x[N-1]);

    cudaFree(d_x); cudaFree(d_bias);
    return 0;
}
