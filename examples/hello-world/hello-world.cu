// Our first CUDA program prints a message from the GPU.
// Every CUDA program has at least one *kernel* — a function
// that runs on the GPU — and a *host* function that launches it.

#include <stdio.h>

// The `__global__` qualifier marks this as a CUDA kernel.
// It runs on the GPU and is called from the CPU.
__global__ void hello() {
    printf("Hello from the GPU!\n");
}

int main() {
    // Launch the kernel with 1 block of 1 thread.
    // The `<<<blocks, threads>>>` syntax is CUDA's launch configuration.
    hello<<<1, 1>>>();

    // `cudaDeviceSynchronize` waits for the GPU to finish
    // before the CPU continues. Without it, the program may
    // exit before the GPU prints anything.
    cudaDeviceSynchronize();
    return 0;
}
