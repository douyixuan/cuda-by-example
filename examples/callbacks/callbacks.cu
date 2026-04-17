// Stream callbacks let you run a host function when all preceding
// operations in a stream complete. Useful for logging, triggering
// CPU work, or coordinating multi-stage pipelines without
// blocking the CPU with synchronize calls.

#include <stdio.h>

const int N = 1 << 18;

__global__ void square(float *data, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) data[i] *= data[i];
}

// This function runs on the CPU when the stream reaches it.
// `userData` passes custom context to the callback.
void CUDART_CB myCallback(cudaStream_t stream, cudaError_t status,
                          void *userData) {
    const char *label = (const char *)userData;
    printf("Callback: '%s' completed (status=%d)\n", label, status);
}

int main() {
    float *d_data;
    cudaMalloc(&d_data, N * sizeof(float));

    cudaStream_t stream;
    cudaStreamCreate(&stream);

    int threads = 256;
    int blocks  = (N + threads - 1) / threads;

    // Enqueue kernel, then a callback, then another kernel.
    // The callback fires between the two kernels — after the
    // first completes but before the second starts.
    square<<<blocks, threads, 0, stream>>>(d_data, N);
    cudaStreamAddCallback(stream, myCallback, (void *)"Phase 1", 0);

    square<<<blocks, threads, 0, stream>>>(d_data, N);
    cudaStreamAddCallback(stream, myCallback, (void *)"Phase 2", 0);

    // Synchronize to ensure all callbacks have fired.
    cudaStreamSynchronize(stream);

    printf("All work complete.\n");

    cudaStreamDestroy(stream);
    cudaFree(d_data);
    return 0;
}
