// CUB DeviceScan computes a prefix sum (scan) over an array.
// Inclusive scan: output[i] = input[0] + ... + input[i].
// Exclusive scan: output[i] = input[0] + ... + input[i-1], output[0] = 0.
// Compare with prefix-sum, which implements this manually with shared memory.
//
// Compile: nvcc -arch=sm_80 cub-device-scan.cu -o cub-device-scan

#include <cub/cub.cuh>
#include <stdio.h>

int main() {
    const int N = 8;
    int h_in[N]  = {1, 2, 3, 4, 5, 6, 7, 8};
    int h_out[N] = {};

    int *d_in, *d_out;
    cudaMalloc(&d_in,  N * sizeof(int));
    cudaMalloc(&d_out, N * sizeof(int));
    cudaMemcpy(d_in, h_in, N * sizeof(int), cudaMemcpyHostToDevice);

    // Two-step CUB pattern: query temp size, then execute.
    void   *d_temp = nullptr;
    size_t  temp_bytes = 0;
    cub::DeviceScan::InclusiveSum(d_temp, temp_bytes, d_in, d_out, N);
    cudaMalloc(&d_temp, temp_bytes);
    cub::DeviceScan::InclusiveSum(d_temp, temp_bytes, d_in, d_out, N);

    cudaMemcpy(h_out, d_out, N * sizeof(int), cudaMemcpyDeviceToHost);

    printf("Inclusive scan:\n");
    for (int i = 0; i < N; i++) printf("  [%d] = %d\n", i, h_out[i]);
    // Expected: 1 3 6 10 15 21 28 36

    cudaFree(d_in);
    cudaFree(d_out);
    cudaFree(d_temp);
    return 0;
}
