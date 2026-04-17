// Zero-copy (mapped) memory lets the GPU access host memory directly
// over PCIe without an explicit cudaMemcpy. Useful when the GPU only
// reads each element once — the transfer happens on-demand and
// overlaps with computation.

#include <stdio.h>

const int N = 1 << 18;

__global__ void scale(float *data, float factor, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) data[i] *= factor;
}

int main() {
    // Mapped host memory requires the DeviceMapHost flag on older GPUs.
    // Modern GPUs (Pascal+) support this by default.
    cudaSetDeviceFlags(cudaDeviceMapHost);

    float *h_data;
    // `cudaHostAllocMapped` pins the memory and makes it GPU-visible.
    // No cudaMalloc or cudaMemcpy needed — the GPU accesses host
    // memory directly through the mapped pointer.
    cudaHostAlloc(&h_data, N * sizeof(float), cudaHostAllocMapped);

    for (int i = 0; i < N; i++) h_data[i] = 1.0f;

    // Get the device pointer corresponding to the mapped host memory.
    float *d_data;
    cudaHostGetDevicePointer(&d_data, h_data, 0);

    // Launch kernel using the device-side pointer.
    // Reads and writes go directly over PCIe — no explicit copy.
    int threads = 256;
    int blocks  = (N + threads - 1) / threads;
    scale<<<blocks, threads>>>(d_data, 3.0f, N);
    cudaDeviceSynchronize();

    // Results are immediately visible in host memory — no copy back.
    printf("h_data[0]=%.1f, h_data[N-1]=%.1f (expected 3.0)\n",
           h_data[0], h_data[N-1]);

    cudaFreeHost(h_data);
    return 0;
}
