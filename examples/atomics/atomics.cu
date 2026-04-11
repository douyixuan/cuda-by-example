// When multiple threads write to the same memory location,
// a race condition occurs — the result depends on which thread
// wins. Atomic operations solve this by making read-modify-write
// indivisible.

#include <stdio.h>

const int N = 1000000;
const int THREADS = 256;

// Without atomics: multiple threads increment the same counter
// simultaneously. Most increments are lost due to races.
__global__ void unsafeIncrement(int *counter, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        // This is a race condition: read-modify-write is not atomic.
        *counter = *counter + 1;
    }
}

// With atomics: `atomicAdd` guarantees each increment is applied
// exactly once, regardless of thread ordering.
__global__ void safeIncrement(int *counter, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        atomicAdd(counter, 1);
    }
}

int main() {
    int blocks = (N + THREADS - 1) / THREADS;
    int *d_counter, h_counter;

    cudaMalloc(&d_counter, sizeof(int));

    // Unsafe version — result will be less than N.
    h_counter = 0;
    cudaMemcpy(d_counter, &h_counter, sizeof(int), cudaMemcpyHostToDevice);
    unsafeIncrement<<<blocks, THREADS>>>(d_counter, N);
    cudaDeviceSynchronize();
    cudaMemcpy(&h_counter, d_counter, sizeof(int), cudaMemcpyDeviceToHost);
    printf("Unsafe counter: %d (expected %d)\n", h_counter, N);

    // Safe version — result is always exactly N.
    h_counter = 0;
    cudaMemcpy(d_counter, &h_counter, sizeof(int), cudaMemcpyHostToDevice);
    safeIncrement<<<blocks, THREADS>>>(d_counter, N);
    cudaDeviceSynchronize();
    cudaMemcpy(&h_counter, d_counter, sizeof(int), cudaMemcpyDeviceToHost);
    printf("Safe counter:   %d (expected %d)\n", h_counter, N);

    cudaFree(d_counter);
    return 0;
}
