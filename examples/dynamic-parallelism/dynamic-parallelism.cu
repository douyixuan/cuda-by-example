// Dynamic parallelism lets a kernel launch other kernels from the GPU
// without returning to the CPU. This enables recursive algorithms
// and adaptive workloads where the GPU decides how to partition work.
//
// Compile with: nvcc -arch=sm_35 -rdc=true dynamic-parallelism.cu -lcudadevrt

#include <stdio.h>

// A child kernel launched from the GPU. Each child processes a
// sub-range of the data independently.
__global__ void childKernel(int *data, int start, int end) {
    int i = start + blockIdx.x * blockDim.x + threadIdx.x;
    if (i < end) data[i] *= 2;
}

// The parent kernel decides at runtime how to split work.
// It launches child kernels from the GPU — no CPU roundtrip.
__global__ void parentKernel(int *data, int n) {
    int tid = threadIdx.x;
    int chunkSize = n / blockDim.x;
    int start = tid * chunkSize;
    int end   = (tid == blockDim.x - 1) ? n : start + chunkSize;

    // Launch a child kernel from the GPU.
    // This requires dynamic parallelism support (sm_35+).
    int count = end - start;
    int threads = 256;
    int blocks  = (count + threads - 1) / threads;
    childKernel<<<blocks, threads>>>(data, start, end);
}

int main() {
    const int N = 1024;
    int h_data[N];
    for (int i = 0; i < N; i++) h_data[i] = i;

    int *d_data;
    cudaMalloc(&d_data, N * sizeof(int));
    cudaMemcpy(d_data, h_data, N * sizeof(int), cudaMemcpyHostToDevice);

    // Launch parent with 4 threads — each launches its own child grid.
    parentKernel<<<1, 4>>>(d_data, N);
    cudaDeviceSynchronize();

    cudaMemcpy(h_data, d_data, N * sizeof(int), cudaMemcpyDeviceToHost);
    printf("h_data[0]=%d, h_data[100]=%d, h_data[1023]=%d (expected 0, 200, 2046)\n",
           h_data[0], h_data[100], h_data[1023]);

    cudaFree(d_data);
    return 0;
}
