// CUDA Graphs capture a sequence of GPU operations (kernels, memcpys)
// into a graph, then replay the entire graph with a single launch.
// This eliminates per-launch CPU overhead and is ideal for workloads
// that repeat the same operations every frame or iteration.

#include <stdio.h>

const int N = 1024;

__global__ void add(const float *a, const float *b, float *c, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) c[i] = a[i] + b[i];
}

__global__ void scale(float *data, float factor, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) data[i] *= factor;
}

int main() {
    float *d_a, *d_b, *d_c;
    cudaMalloc(&d_a, N * sizeof(float));
    cudaMalloc(&d_b, N * sizeof(float));
    cudaMalloc(&d_c, N * sizeof(float));

    int threads = 256;
    int blocks  = (N + threads - 1) / threads;

    // Begin capturing operations into a graph.
    // Everything between Begin and End is recorded, not executed.
    cudaStream_t stream;
    cudaStreamCreate(&stream);

    cudaGraph_t graph;
    cudaStreamBeginCapture(stream, cudaStreamCaptureModeGlobal);

    add<<<blocks, threads, 0, stream>>>(d_a, d_b, d_c, N);
    scale<<<blocks, threads, 0, stream>>>(d_c, 2.0f, N);

    cudaStreamEndCapture(stream, &graph);

    // Instantiate the graph into an executable form.
    // This is a one-time cost — the executable can be reused.
    cudaGraphExec_t instance;
    cudaGraphInstantiate(&instance, graph, NULL, NULL, 0);

    // Launch the graph. A single call replays both kernels
    // with minimal CPU overhead — much faster than two separate launches.
    for (int iter = 0; iter < 100; iter++) {
        cudaGraphLaunch(instance, stream);
    }
    cudaStreamSynchronize(stream);

    printf("Launched graph 100 times (add + scale per launch)\n");

    cudaGraphExecDestroy(instance);
    cudaGraphDestroy(graph);
    cudaStreamDestroy(stream);
    cudaFree(d_a);
    cudaFree(d_b);
    cudaFree(d_c);
    return 0;
}
