// CUDA supports function pointers on the device, letting you select
// different operations at runtime without recompiling. The host
// picks which device function to call and passes its address to
// the kernel.

#include <stdio.h>

// Device functions that can be called through a pointer.
// `__device__` functions run on the GPU but can't be launched directly.
__device__ float add(float a, float b) { return a + b; }
__device__ float mul(float a, float b) { return a * b; }
__device__ float sub(float a, float b) { return a - b; }

// Type alias for device function pointers.
typedef float (*OpFunc)(float, float);

// The kernel receives a function pointer and calls it.
__global__ void apply(const float *a, const float *b, float *c,
                      OpFunc op, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) c[i] = op(a[i], b[i]);
}

// These global variables hold device-side function addresses.
// `cudaMemcpyFromSymbol` copies them to the host.
__device__ OpFunc d_add = add;
__device__ OpFunc d_mul = mul;
__device__ OpFunc d_sub = sub;

int main() {
    const int N = 256;
    float h_a[N], h_b[N], h_c[N];
    for (int i = 0; i < N; i++) { h_a[i] = (float)i; h_b[i] = 10.0f; }

    float *d_a, *d_b, *d_c;
    cudaMalloc(&d_a, N * sizeof(float));
    cudaMalloc(&d_b, N * sizeof(float));
    cudaMalloc(&d_c, N * sizeof(float));
    cudaMemcpy(d_a, h_a, N * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(d_b, h_b, N * sizeof(float), cudaMemcpyHostToDevice);

    // Copy the device function pointer to the host so we can pass it
    // as a kernel argument.
    OpFunc h_op;
    cudaMemcpyFromSymbol(&h_op, d_mul, sizeof(OpFunc));

    apply<<<(N+63)/64, 64>>>(d_a, d_b, d_c, h_op, N);
    cudaMemcpy(h_c, d_c, N * sizeof(float), cudaMemcpyDeviceToHost);

    printf("5 * 10 = %.0f, 100 * 10 = %.0f\n", h_c[5], h_c[100]);

    cudaFree(d_a); cudaFree(d_b); cudaFree(d_c);
    return 0;
}
