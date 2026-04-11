// Unified Memory lets the CPU and GPU share a single pointer.
// No explicit `cudaMemcpy` needed — the CUDA runtime migrates
// pages between host and device automatically.

#include <stdio.h>

const int N = 1 << 20; // 1M elements

__global__ void scale(float *data, float factor, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) data[i] *= factor;
}

int main() {
    float *data;

    // `cudaMallocManaged` allocates Unified Memory.
    // The returned pointer is valid on both CPU and GPU.
    cudaMallocManaged(&data, N * sizeof(float));

    // Initialize on the CPU — no copy needed.
    for (int i = 0; i < N; i++) data[i] = (float)i;

    int threads = 256;
    int blocks  = (N + threads - 1) / threads;
    scale<<<blocks, threads>>>(data, 2.0f, N);

    // After the kernel, synchronize before reading on the CPU.
    // The runtime migrates modified pages back to host memory.
    cudaDeviceSynchronize();

    // Read results directly through the same pointer.
    printf("data[0]=%.0f, data[1]=%.0f, data[N-1]=%.0f\n",
           data[0], data[1], data[N-1]);

    // Unified Memory is freed with the same cudaFree.
    cudaFree(data);
    return 0;
}
