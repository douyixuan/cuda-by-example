// C++ templates work in CUDA kernels, letting you write type-generic
// GPU code. The compiler generates specialized versions for each
// type — no runtime cost. Templates also enable compile-time
// loop unrolling and constant folding.

#include <stdio.h>

// A templated kernel that works with any numeric type.
// The compiler generates separate GPU code for float and int.
template<typename T>
__global__ void vectorScale(T *data, T factor, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) data[i] *= factor;
}

// Template with a compile-time constant: the compiler unrolls
// the inner loop completely since UNROLL_FACTOR is known at compile time.
template<int UNROLL_FACTOR>
__global__ void unrolledAdd(float *data, float val, int n) {
    int base = (blockIdx.x * blockDim.x + threadIdx.x) * UNROLL_FACTOR;
    #pragma unroll
    for (int j = 0; j < UNROLL_FACTOR; j++) {
        int i = base + j;
        if (i < n) data[i] += val;
    }
}

int main() {
    const int N = 1024;
    int threads = 256;
    int blocks  = (N + threads - 1) / threads;

    // Float version.
    float h_float[N];
    for (int i = 0; i < N; i++) h_float[i] = (float)i;
    float *d_float;
    cudaMalloc(&d_float, N * sizeof(float));
    cudaMemcpy(d_float, h_float, N * sizeof(float), cudaMemcpyHostToDevice);
    vectorScale<float><<<blocks, threads>>>(d_float, 3.0f, N);
    cudaMemcpy(h_float, d_float, N * sizeof(float), cudaMemcpyDeviceToHost);
    printf("float: h[10]=%.0f (expected 30)\n", h_float[10]);

    // Int version — same kernel template, different type.
    int h_int[N];
    for (int i = 0; i < N; i++) h_int[i] = i;
    int *d_int;
    cudaMalloc(&d_int, N * sizeof(int));
    cudaMemcpy(d_int, h_int, N * sizeof(int), cudaMemcpyHostToDevice);
    vectorScale<int><<<blocks, threads>>>(d_int, 5, N);
    cudaMemcpy(h_int, d_int, N * sizeof(int), cudaMemcpyDeviceToHost);
    printf("int:   h[10]=%d  (expected 50)\n", h_int[10]);

    // Unrolled version with compile-time factor.
    int unrollBlocks = (N + threads * 4 - 1) / (threads * 4);
    unrolledAdd<4><<<unrollBlocks, threads>>>(d_float, 1.0f, N);
    cudaMemcpy(h_float, d_float, N * sizeof(float), cudaMemcpyDeviceToHost);
    printf("unroll: h[10]=%.0f (expected 31)\n", h_float[10]);

    cudaFree(d_float);
    cudaFree(d_int);
    return 0;
}
