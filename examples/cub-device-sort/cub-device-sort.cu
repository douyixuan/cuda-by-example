// CUB (CUDA Unbound) is NVIDIA's official header-only GPU primitives library.
// CUB DeviceSort sorts an array using radix sort — the fastest GPU sort
// for integer and floating-point keys. Key-value pairs keep values
// aligned with their keys after sorting.
//
// Source: [github.com/NVIDIA/cccl](https://github.com/NVIDIA/cccl/tree/main/cub/cub/device) — device/
// Compile: nvcc -arch=sm_80 cub-device-sort.cu -o cub-device-sort

#include <cub/cub.cuh>
#include <stdio.h>

int main() {
    const int N = 8;
    int h_keys[N]   = {5, 2, 8, 1, 9, 3, 7, 4};
    int h_values[N] = {0, 1, 2, 3, 4, 5, 6, 7}; // original indices

    int *d_keys_in,  *d_keys_out;
    int *d_vals_in,  *d_vals_out;
    cudaMalloc(&d_keys_in,  N * sizeof(int));
    cudaMalloc(&d_keys_out, N * sizeof(int));
    cudaMalloc(&d_vals_in,  N * sizeof(int));
    cudaMalloc(&d_vals_out, N * sizeof(int));
    cudaMemcpy(d_keys_in, h_keys,   N * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_vals_in, h_values, N * sizeof(int), cudaMemcpyHostToDevice);

    // Two-step CUB pattern: query temp size, then execute.
    void   *d_temp = nullptr;
    size_t  temp_bytes = 0;
    cub::DeviceRadixSort::SortPairs(d_temp, temp_bytes,
        d_keys_in, d_keys_out, d_vals_in, d_vals_out, N);
    cudaMalloc(&d_temp, temp_bytes);
    cub::DeviceRadixSort::SortPairs(d_temp, temp_bytes,
        d_keys_in, d_keys_out, d_vals_in, d_vals_out, N);

    int h_keys_out[N], h_vals_out[N];
    cudaMemcpy(h_keys_out, d_keys_out, N * sizeof(int), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_vals_out, d_vals_out, N * sizeof(int), cudaMemcpyDeviceToHost);

    printf("Sorted keys (original index):\n");
    for (int i = 0; i < N; i++)
        printf("  %d (was at index %d)\n", h_keys_out[i], h_vals_out[i]);
    // Expected: 1 2 3 4 5 7 8 9 (ascending)

    cudaFree(d_keys_in);  cudaFree(d_keys_out);
    cudaFree(d_vals_in);  cudaFree(d_vals_out);
    cudaFree(d_temp);
    return 0;
}
