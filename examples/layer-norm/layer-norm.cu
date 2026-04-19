// Layer Normalization normalizes each token's feature vector to zero mean
// and unit variance, then applies learned scale (gamma) and shift (beta).
// Used in every transformer block. Requires two passes: mean, then variance.
// feature_size must be a multiple of 32 to avoid warp divergence.
//
// Compile: nvcc -arch=sm_80 layer-norm.cu -o layer-norm

#include <stdio.h>
#include <math.h>

const int SEQ    = 4;    // number of tokens
const int FEAT   = 128;  // feature dimension (must be multiple of 32)
const float EPS  = 1e-5f;

// One block per token. Threads reduce mean and variance in shared memory.
__global__ void layerNorm(const float *x, float *y,
                          const float *gamma, const float *beta,
                          int feat) {
    extern __shared__ float smem[];
    int tid = threadIdx.x;
    int base = blockIdx.x * feat;

    // Pass 1: compute mean.
    smem[tid] = (tid < feat) ? x[base + tid] : 0.0f;
    __syncthreads();
    for (int s = blockDim.x / 2; s > 0; s >>= 1) {
        if (tid < s) smem[tid] += smem[tid + s];
        __syncthreads();
    }
    float mean = smem[0] / feat;
    __syncthreads();

    // Pass 2: compute variance.
    float diff = (tid < feat) ? (x[base + tid] - mean) : 0.0f;
    smem[tid] = diff * diff;
    __syncthreads();
    for (int s = blockDim.x / 2; s > 0; s >>= 1) {
        if (tid < s) smem[tid] += smem[tid + s];
        __syncthreads();
    }
    float inv_std = rsqrtf(smem[0] / feat + EPS);

    // Normalize and apply affine transform.
    if (tid < feat)
        y[base + tid] = gamma[tid] * (x[base + tid] - mean) * inv_std + beta[tid];
}

int main() {
    const int total = SEQ * FEAT;
    float h_x[total], h_y[total], h_gamma[FEAT], h_beta[FEAT];
    for (int i = 0; i < total; i++) h_x[i] = (float)(i % FEAT) / FEAT;
    for (int i = 0; i < FEAT;  i++) { h_gamma[i] = 1.0f; h_beta[i] = 0.0f; }

    float *d_x, *d_y, *d_gamma, *d_beta;
    cudaMalloc(&d_x,     total * sizeof(float));
    cudaMalloc(&d_y,     total * sizeof(float));
    cudaMalloc(&d_gamma, FEAT  * sizeof(float));
    cudaMalloc(&d_beta,  FEAT  * sizeof(float));
    cudaMemcpy(d_x,     h_x,     total * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(d_gamma, h_gamma, FEAT  * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(d_beta,  h_beta,  FEAT  * sizeof(float), cudaMemcpyHostToDevice);

    layerNorm<<<SEQ, FEAT, FEAT * sizeof(float)>>>(d_x, d_y, d_gamma, d_beta, FEAT);
    cudaMemcpy(h_y, d_y, total * sizeof(float), cudaMemcpyDeviceToHost);

    // After LayerNorm with gamma=1, beta=0: mean≈0, std≈1 per token.
    printf("token 0: y[0]=%.4f  y[63]=%.4f  y[127]=%.4f\n",
           h_y[0], h_y[63], h_y[127]);

    cudaFree(d_x); cudaFree(d_y); cudaFree(d_gamma); cudaFree(d_beta);
    return 0;
}
