// CUDA streams let you overlap computation and data transfer.
// By default all operations run in the default stream and execute
// sequentially. Named streams enable true concurrency.

#include <stdio.h>

const int N = 1 << 20;
const int CHUNK = N / 4; // process in 4 chunks

__global__ void scale(float *data, float factor, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) data[i] *= factor;
}

int main() {
    float *h_data, *d_data;
    size_t bytes = N * sizeof(float);

    // Pinned (page-locked) host memory is required for async transfers.
    // Regular malloc'd memory cannot be used with cudaMemcpyAsync.
    cudaMallocHost(&h_data, bytes);
    cudaMalloc(&d_data, bytes);

    for (int i = 0; i < N; i++) h_data[i] = 1.0f;

    // Create two streams. Operations in different streams can
    // overlap with each other on the GPU.
    cudaStream_t s0, s1;
    cudaStreamCreate(&s0);
    cudaStreamCreate(&s1);

    int threads = 256;
    size_t chunkBytes = CHUNK * sizeof(float);

    // Interleave H→D copy and kernel across two streams.
    // Stream s0 handles chunks 0 and 2; s1 handles chunks 1 and 3.
    // While s0's kernel runs on chunk 0, s1 can copy chunk 1.
    for (int c = 0; c < 4; c++) {
        cudaStream_t s = (c % 2 == 0) ? s0 : s1;
        int offset = c * CHUNK;
        cudaMemcpyAsync(d_data + offset, h_data + offset,
                        chunkBytes, cudaMemcpyHostToDevice, s);
        int blocks = (CHUNK + threads - 1) / threads;
        scale<<<blocks, threads, 0, s>>>(d_data + offset, 2.0f, CHUNK);
        cudaMemcpyAsync(h_data + offset, d_data + offset,
                        chunkBytes, cudaMemcpyDeviceToHost, s);
    }

    // Wait for both streams to finish before reading results.
    cudaStreamSynchronize(s0);
    cudaStreamSynchronize(s1);

    printf("h_data[0]=%.1f, h_data[N-1]=%.1f (expected 2.0)\n",
           h_data[0], h_data[N-1]);

    cudaStreamDestroy(s0);
    cudaStreamDestroy(s1);
    cudaFreeHost(h_data);
    cudaFree(d_data);
    return 0;
}
