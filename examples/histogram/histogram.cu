// A histogram counts how many times each value appears. On the GPU
// we use atomicAdd to let thousands of threads update bin counts
// simultaneously. Shared memory privatization reduces contention
// on the global histogram.

#include <stdio.h>

const int N    = 1 << 20;
const int BINS = 256;

// Phase 1: each block builds a private histogram in shared memory.
// Phase 2: merge private histograms into the global one.
__global__ void histogram(const unsigned char *data, int *hist, int n) {
    __shared__ int localHist[BINS];

    int tid = threadIdx.x;
    // Clear local bins — each thread zeroes a few bins.
    for (int b = tid; b < BINS; b += blockDim.x)
        localHist[b] = 0;
    __syncthreads();

    // Count into shared memory — much less contention than global.
    int gid = blockIdx.x * blockDim.x + tid;
    int stride = blockDim.x * gridDim.x;
    for (int i = gid; i < n; i += stride)
        atomicAdd(&localHist[data[i]], 1);
    __syncthreads();

    // Merge local histogram into global.
    for (int b = tid; b < BINS; b += blockDim.x)
        atomicAdd(&hist[b], localHist[b]);
}

int main() {
    unsigned char *h_data = new unsigned char[N];
    for (int i = 0; i < N; i++) h_data[i] = i % BINS;

    unsigned char *d_data;
    int *d_hist;
    cudaMalloc(&d_data, N);
    cudaMalloc(&d_hist, BINS * sizeof(int));
    cudaMemset(d_hist, 0, BINS * sizeof(int));
    cudaMemcpy(d_data, h_data, N, cudaMemcpyHostToDevice);

    histogram<<<256, 256>>>(d_data, d_hist, N);

    int h_hist[BINS];
    cudaMemcpy(h_hist, d_hist, BINS * sizeof(int), cudaMemcpyDeviceToHost);

    // Each bin should have N/BINS = 4096 counts.
    printf("bin[0]=%d, bin[255]=%d (expected %d)\n",
           h_hist[0], h_hist[255], N / BINS);

    cudaFree(d_data);
    cudaFree(d_hist);
    delete[] h_data;
    return 0;
}
