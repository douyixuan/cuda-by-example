// Instruction-Level Parallelism (ILP) means each thread does more
// independent work, giving the GPU's pipeline more instructions to
// overlap. Instead of one element per thread, processing multiple
// elements reduces stalls from memory latency.

#include <stdio.h>

const int N = 1 << 22;

// ILP=1: each thread processes one element.
// The GPU must hide all latency through warp-level parallelism alone.
__global__ void ilp1(const float *in, float *out, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) out[i] = sinf(in[i]);
}

// ILP=4: each thread processes four elements.
// While one load is in flight, the GPU can execute arithmetic
// on previously loaded values — better pipeline utilization.
__global__ void ilp4(const float *in, float *out, int n) {
    int i = (blockIdx.x * blockDim.x + threadIdx.x) * 4;
    if (i + 3 < n) {
        float a = in[i],   b = in[i+1];
        float c = in[i+2], d = in[i+3];
        out[i]   = sinf(a);
        out[i+1] = sinf(b);
        out[i+2] = sinf(c);
        out[i+3] = sinf(d);
    }
}

int main() {
    float *d_in, *d_out;
    cudaMalloc(&d_in,  N * sizeof(float));
    cudaMalloc(&d_out, N * sizeof(float));

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    int threads = 256;

    cudaEventRecord(start);
    for (int r = 0; r < 50; r++)
        ilp1<<<(N + threads - 1) / threads, threads>>>(d_in, d_out, N);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    float ms1 = 0;
    cudaEventElapsedTime(&ms1, start, stop);

    cudaEventRecord(start);
    for (int r = 0; r < 50; r++)
        ilp4<<<(N/4 + threads - 1) / threads, threads>>>(d_in, d_out, N);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    float ms4 = 0;
    cudaEventElapsedTime(&ms4, start, stop);

    printf("ILP=1: %.2f ms, ILP=4: %.2f ms (%.1fx speedup)\n",
           ms1, ms4, ms1 / ms4);

    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(d_in);
    cudaFree(d_out);
    return 0;
}
