// The Occupancy API helps you choose the optimal block size for a kernel.
// Instead of guessing, `cudaOccupancyMaxPotentialBlockSize` considers
// register usage, shared memory, and hardware limits to find the
// block size that maximizes GPU utilization.

#include <stdio.h>

__global__ void myKernel(float *data, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) data[i] = sqrtf(data[i]) + 1.0f;
}

int main() {
    const int N = 1 << 20;
    float *d_data;
    cudaMalloc(&d_data, N * sizeof(float));

    // Let the runtime choose the optimal block size.
    // `minGridSize` is the minimum grid size for full occupancy.
    // `blockSize` is the recommended threads per block.
    int minGridSize, blockSize;
    cudaOccupancyMaxPotentialBlockSize(
        &minGridSize, &blockSize, myKernel, 0, N);

    int gridSize = (N + blockSize - 1) / blockSize;

    printf("Recommended: blockSize=%d, minGridSize=%d\n",
           blockSize, minGridSize);
    printf("Using:       gridSize=%d, blockSize=%d\n",
           gridSize, blockSize);

    // Query the actual occupancy achieved.
    int maxActiveBlocks;
    cudaOccupancyMaxActiveBlocksPerMultiprocessor(
        &maxActiveBlocks, myKernel, blockSize, 0);

    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, 0);
    float occupancy = (float)(maxActiveBlocks * blockSize) /
                      prop.maxThreadsPerMultiProcessor;
    printf("Occupancy:   %.0f%%\n", occupancy * 100);

    myKernel<<<gridSize, blockSize>>>(d_data, N);
    cudaDeviceSynchronize();
    printf("Kernel completed successfully.\n");

    cudaFree(d_data);
    return 0;
}
