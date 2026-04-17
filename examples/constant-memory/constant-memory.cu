// Constant memory is a read-only cache optimized for broadcast access.
// When all threads in a warp read the same address, the hardware
// serves it in a single cycle — much faster than global memory.

#include <stdio.h>

// `__constant__` places data in a dedicated 64 KB cache on the GPU.
// Ideal for lookup tables, filter coefficients, or any data that
// every thread reads but none modify.
__constant__ float filter[5];

__global__ void applyFilter(const float *input, float *output, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= 2 && i < n - 2) {
        // All threads read the same filter[] values — constant
        // memory broadcasts to the entire warp in one transaction.
        output[i] = filter[0] * input[i-2]
                   + filter[1] * input[i-1]
                   + filter[2] * input[i]
                   + filter[3] * input[i+1]
                   + filter[4] * input[i+2];
    }
}

int main() {
    const int N = 1024;
    float h_filter[5] = {0.1f, 0.2f, 0.4f, 0.2f, 0.1f};

    // Copy filter coefficients from host to constant memory.
    // `cudaMemcpyToSymbol` is the only way to write constant memory.
    cudaMemcpyToSymbol(filter, h_filter, 5 * sizeof(float));

    float *h_in = new float[N];
    float *h_out = new float[N];
    for (int i = 0; i < N; i++) h_in[i] = (float)i;

    float *d_in, *d_out;
    cudaMalloc(&d_in,  N * sizeof(float));
    cudaMalloc(&d_out, N * sizeof(float));
    cudaMemcpy(d_in, h_in, N * sizeof(float), cudaMemcpyHostToDevice);

    applyFilter<<<(N+255)/256, 256>>>(d_in, d_out, N);
    cudaMemcpy(h_out, d_out, N * sizeof(float), cudaMemcpyDeviceToHost);

    // Verify: position 2 should be 0.1*0 + 0.2*1 + 0.4*2 + 0.2*3 + 0.1*4 = 2.0
    printf("h_out[2]=%.1f (expected 2.0)\n", h_out[2]);

    cudaFree(d_in);
    cudaFree(d_out);
    delete[] h_in;
    delete[] h_out;
    return 0;
}
