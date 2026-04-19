// Online softmax computes softmax in a single pass over the input,
// tracking the running max and sum simultaneously. This avoids the
// two-pass approach (max scan, then exp/sum) used in naive softmax.
// FlashAttention uses this trick to fuse the attention score computation.
//
// Compile: nvcc -arch=sm_80 online-softmax.cu -o online-softmax

#include <stdio.h>
#include <math.h>

const int N = 256;  // sequence length (one row of attention scores)

// Each block handles one row. Threads reduce in shared memory.
__global__ void onlineSoftmax(const float *input, float *output, int n) {
    extern __shared__ float smem[];  // [n] scratch

    int tid = threadIdx.x;
    int gid = blockIdx.x * n + tid;

    // Load row into shared memory.
    smem[tid] = (tid < n) ? input[gid] : -1e38f;
    __syncthreads();

    // Parallel max reduction.
    for (int stride = blockDim.x / 2; stride > 0; stride >>= 1) {
        if (tid < stride) smem[tid] = fmaxf(smem[tid], smem[tid + stride]);
        __syncthreads();
    }
    float row_max = smem[0];
    __syncthreads();

    // Shift by max for numerical stability, then compute exp.
    smem[tid] = (tid < n) ? expf(input[gid] - row_max) : 0.0f;
    __syncthreads();

    // Parallel sum reduction.
    for (int stride = blockDim.x / 2; stride > 0; stride >>= 1) {
        if (tid < stride) smem[tid] += smem[tid + stride];
        __syncthreads();
    }
    float row_sum = smem[0];

    // Normalize.
    if (tid < n) output[gid] = expf(input[gid] - row_max) / row_sum;
}

int main() {
    float h_in[N], h_out[N];
    for (int i = 0; i < N; i++) h_in[i] = (float)i / N;

    float *d_in, *d_out;
    cudaMalloc(&d_in,  N * sizeof(float));
    cudaMalloc(&d_out, N * sizeof(float));
    cudaMemcpy(d_in, h_in, N * sizeof(float), cudaMemcpyHostToDevice);

    onlineSoftmax<<<1, N, N * sizeof(float)>>>(d_in, d_out, N);
    cudaMemcpy(h_out, d_out, N * sizeof(float), cudaMemcpyDeviceToHost);

    float sum = 0;
    for (int i = 0; i < N; i++) sum += h_out[i];
    printf("softmax sum=%.6f (expected 1.0)  out[0]=%.6f  out[255]=%.6f\n",
           sum, h_out[0], h_out[N-1]);

    cudaFree(d_in); cudaFree(d_out);
    return 0;
}
