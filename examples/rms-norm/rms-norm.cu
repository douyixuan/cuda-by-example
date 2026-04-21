// RMSNorm normalizes by root-mean-square instead of mean+variance.
// Simpler than LayerNorm (no mean subtraction), used in LLaMA and Mistral.
// One pass: compute sum of squares, then normalize.
//
// Source: [github.com/meta-llama/llama](https://github.com/meta-llama/llama/blob/main/llama/model.py) — RMSNorm
// Compile: nvcc -arch=sm_80 rms-norm.cu -o rms-norm

#include <stdio.h>
#include <math.h>

const int SEQ   = 4;
const int FEAT  = 128;
const float EPS = 1e-6f;

__global__ void rmsNorm(const float *x, float *y, const float *weight, int feat) {
    extern __shared__ float smem[];
    int tid  = threadIdx.x;
    int base = blockIdx.x * feat;

    // Compute sum of squares.
    float val = (tid < feat) ? x[base + tid] : 0.0f;
    smem[tid] = val * val;
    __syncthreads();

    for (int s = blockDim.x / 2; s > 0; s >>= 1) {
        if (tid < s) smem[tid] += smem[tid + s];
        __syncthreads();
    }

    // rms = sqrt(mean(x^2) + eps)
    float inv_rms = rsqrtf(smem[0] / feat + EPS);

    if (tid < feat)
        y[base + tid] = weight[tid] * x[base + tid] * inv_rms;
}

int main() {
    const int total = SEQ * FEAT;
    float h_x[total], h_y[total], h_w[FEAT];
    for (int i = 0; i < total; i++) h_x[i] = (float)(i % FEAT) / FEAT;
    for (int i = 0; i < FEAT;  i++) h_w[i] = 1.0f;

    float *d_x, *d_y, *d_w;
    cudaMalloc(&d_x, total * sizeof(float));
    cudaMalloc(&d_y, total * sizeof(float));
    cudaMalloc(&d_w, FEAT  * sizeof(float));
    cudaMemcpy(d_x, h_x, total * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(d_w, h_w, FEAT  * sizeof(float), cudaMemcpyHostToDevice);

    rmsNorm<<<SEQ, FEAT, FEAT * sizeof(float)>>>(d_x, d_y, d_w, FEAT);
    cudaMemcpy(h_y, d_y, total * sizeof(float), cudaMemcpyDeviceToHost);

    printf("token 0: y[0]=%.4f  y[63]=%.4f  y[127]=%.4f\n",
           h_y[0], h_y[63], h_y[127]);

    cudaFree(d_x); cudaFree(d_y); cudaFree(d_w);
    return 0;
}
