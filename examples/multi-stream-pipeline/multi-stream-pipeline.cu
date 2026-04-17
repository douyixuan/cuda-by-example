// A multi-stream pipeline overlaps copy and compute across several
// streams, keeping both the copy engine and compute engine busy.
// This pattern maximizes GPU utilization for data-parallel workloads.

#include <stdio.h>

const int N         = 1 << 22;
const int NSTREAMS  = 4;
const int CHUNK     = N / NSTREAMS;

__global__ void process(float *data, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) data[i] = sqrtf(data[i]) + 1.0f;
}

int main() {
    size_t bytes      = N * sizeof(float);
    size_t chunkBytes = CHUNK * sizeof(float);

    // Pinned memory is required for async transfers.
    float *h_data;
    cudaMallocHost(&h_data, bytes);
    for (int i = 0; i < N; i++) h_data[i] = (float)i;

    float *d_data;
    cudaMalloc(&d_data, bytes);

    // Create multiple streams for overlapping work.
    cudaStream_t streams[NSTREAMS];
    for (int s = 0; s < NSTREAMS; s++)
        cudaStreamCreate(&streams[s]);

    int threads = 256;
    int blocks  = (CHUNK + threads - 1) / threads;

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    cudaEventRecord(start);

    // Stage 1: Issue all H→D copies across streams.
    for (int s = 0; s < NSTREAMS; s++) {
        int offset = s * CHUNK;
        cudaMemcpyAsync(d_data + offset, h_data + offset,
                        chunkBytes, cudaMemcpyHostToDevice, streams[s]);
    }

    // Stage 2: Issue all kernels — each depends only on its own copy.
    for (int s = 0; s < NSTREAMS; s++) {
        int offset = s * CHUNK;
        process<<<blocks, threads, 0, streams[s]>>>(d_data + offset, CHUNK);
    }

    // Stage 3: Issue all D→H copies — each depends on its own kernel.
    for (int s = 0; s < NSTREAMS; s++) {
        int offset = s * CHUNK;
        cudaMemcpyAsync(h_data + offset, d_data + offset,
                        chunkBytes, cudaMemcpyDeviceToHost, streams[s]);
    }

    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    float ms = 0;
    cudaEventElapsedTime(&ms, start, stop);

    printf("Pipeline with %d streams: %.2f ms\n", NSTREAMS, ms);
    printf("h_data[0]=%.2f (expected %.2f)\n", h_data[0], sqrtf(0.0f) + 1.0f);

    for (int s = 0; s < NSTREAMS; s++)
        cudaStreamDestroy(streams[s]);
    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFreeHost(h_data);
    cudaFree(d_data);
    return 0;
}
