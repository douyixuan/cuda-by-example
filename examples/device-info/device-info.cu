// Before writing kernels, it's useful to query the GPU's capabilities.
// `cudaGetDeviceProperties` fills a struct with everything you need to know
// about the device: memory size, thread limits, compute capability, and more.

#include <stdio.h>

int main() {
    int deviceCount;
    cudaGetDeviceCount(&deviceCount);
    printf("CUDA devices found: %d\n", deviceCount);

    // Loop over all available GPUs. Most machines have one,
    // but multi-GPU systems are common in HPC and ML clusters.
    for (int i = 0; i < deviceCount; i++) {
        cudaDeviceProp prop;
        cudaGetDeviceProperties(&prop, i);

        printf("\nDevice %d: %s\n", i, prop.name);

        // Compute capability is the GPU's feature version.
        // 8.6 means Ampere architecture; 9.0 means Hopper.
        printf("  Compute capability:     %d.%d\n",
               prop.major, prop.minor);

        // Total global memory is the GPU's VRAM — the main
        // memory pool for device allocations.
        printf("  Global memory:          %.0f MB\n",
               (float)prop.totalGlobalMem / (1024 * 1024));

        // A Streaming Multiprocessor (SM) is the GPU's core unit.
        // Each SM runs many threads concurrently.
        printf("  Multiprocessors (SMs):  %d\n",
               prop.multiProcessorCount);

        // The maximum number of threads per block constrains
        // how you configure kernel launches.
        printf("  Max threads per block:  %d\n",
               prop.maxThreadsPerBlock);

        // Warp size is always 32 on NVIDIA GPUs. Threads within
        // a warp execute in lockstep — this is the fundamental
        // unit of GPU parallelism.
        printf("  Warp size:              %d\n", prop.warpSize);
    }
    return 0;
}
