// CUB (CUDA Unbound) is NVIDIA's official header-only GPU primitives library.
// CUB DeviceReduce reduces an entire array to a single value in one call.
// The two-step pattern — query temp storage size, then execute — is the
// standard CUB device-level API used by DeviceScan and DeviceSort too.
//
// Source: [github.com/NVIDIA/cccl](https://github.com/NVIDIA/cccl/tree/main/cub/cub/device) — device/
// Compile: nvcc -arch=sm_80 cub-device-reduce.cu -o cub-device-reduce

#include <cub/cub.cuh>
#include <stdio.h>

int main() {
    const int N = 1024;
    float h_in[N];
    for (int i = 0; i < N; i++) h_in[i] = 1.0f;

    float *d_in, *d_out;
    cudaMalloc(&d_in,  N * sizeof(float));
    cudaMalloc(&d_out, sizeof(float));
    cudaMemcpy(d_in, h_in, N * sizeof(float), cudaMemcpyHostToDevice);

    // Step 1: query how much temporary storage CUB needs.
    void   *d_temp = nullptr;
    size_t  temp_bytes = 0;
    cub::DeviceReduce::Sum(d_temp, temp_bytes, d_in, d_out, N);

    // Step 2: allocate temp storage and run the reduction.
    cudaMalloc(&d_temp, temp_bytes);
    cub::DeviceReduce::Sum(d_temp, temp_bytes, d_in, d_out, N);

    float h_out;
    cudaMemcpy(&h_out, d_out, sizeof(float), cudaMemcpyDeviceToHost);
    printf("Sum = %.0f (expected %d)\n", h_out, N);

    cudaFree(d_in);
    cudaFree(d_out);
    cudaFree(d_temp);
    return 0;
}
