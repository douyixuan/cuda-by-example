// Every CUDA API call returns an error code. Ignoring these is the
// fastest way to write bugs that are impossible to diagnose.
// A simple macro makes error checking painless.

#include <stdio.h>
#include <stdlib.h>

// `cudaCheck` wraps any CUDA call. If it fails, it prints the
// error string, file, and line number, then exits.
// Usage: cudaCheck(cudaMalloc(&ptr, size));
#define cudaCheck(call)                                                  \
    do {                                                                 \
        cudaError_t err = (call);                                        \
        if (err != cudaSuccess) {                                        \
            fprintf(stderr, "CUDA error at %s:%d — %s\n",               \
                    __FILE__, __LINE__, cudaGetErrorString(err));        \
            exit(EXIT_FAILURE);                                          \
        }                                                                \
    } while (0)

__global__ void kernel(float *data, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) data[i] *= 2.0f;
}

int main() {
    const int N = 256;
    float *d_data;

    // Wrap every allocation and copy with cudaCheck.
    // If the GPU runs out of memory or the pointer is invalid,
    // you'll get a clear error message instead of a silent crash.
    cudaCheck(cudaMalloc(&d_data, N * sizeof(float)));

    // After a kernel launch, check for configuration errors.
    // Note: kernel errors are asynchronous — cudaGetLastError()
    // captures them after the launch, not during.
    kernel<<<1, N>>>(d_data, N);
    cudaCheck(cudaGetLastError());

    // cudaDeviceSynchronize flushes the GPU queue and surfaces
    // any runtime errors that occurred during kernel execution.
    cudaCheck(cudaDeviceSynchronize());

    cudaCheck(cudaFree(d_data));
    printf("All CUDA calls succeeded.\n");
    return 0;
}
