// Merge sort on the GPU: each thread block sorts a small chunk
// independently, then a merge step combines sorted chunks.
// This example shows a simple bitonic-style sort within blocks.

#include <stdio.h>

const int N = 1024;

// Bitonic sort within a block. Each thread handles one element.
// The network of compare-and-swap operations sorts in O(log²n) steps.
__global__ void bitonicSort(int *data, int n) {
    extern __shared__ int sdata[];
    int tid = threadIdx.x;
    sdata[tid] = (tid < n) ? data[blockIdx.x * blockDim.x + tid] : INT_MAX;
    __syncthreads();

    // Bitonic merge network: k is the subsequence size,
    // j is the compare distance. Every pair is compared
    // and swapped to build sorted bitonic sequences.
    for (int k = 2; k <= blockDim.x; k <<= 1) {
        for (int j = k >> 1; j > 0; j >>= 1) {
            int partner = tid ^ j;
            if (partner > tid) {
                bool ascending = ((tid & k) == 0);
                if ((ascending && sdata[tid] > sdata[partner]) ||
                    (!ascending && sdata[tid] < sdata[partner])) {
                    int tmp = sdata[tid];
                    sdata[tid] = sdata[partner];
                    sdata[partner] = tmp;
                }
            }
            __syncthreads();
        }
    }

    if (tid < n) data[blockIdx.x * blockDim.x + tid] = sdata[tid];
}

int main() {
    int h_data[N];
    for (int i = 0; i < N; i++) h_data[i] = N - i;

    int *d_data;
    cudaMalloc(&d_data, N * sizeof(int));
    cudaMemcpy(d_data, h_data, N * sizeof(int), cudaMemcpyHostToDevice);

    bitonicSort<<<1, N, N * sizeof(int)>>>(d_data, N);
    cudaMemcpy(h_data, d_data, N * sizeof(int), cudaMemcpyDeviceToHost);

    printf("First 5: %d %d %d %d %d\n",
           h_data[0], h_data[1], h_data[2], h_data[3], h_data[4]);
    printf("Last  5: %d %d %d %d %d\n",
           h_data[N-5], h_data[N-4], h_data[N-3], h_data[N-2], h_data[N-1]);

    cudaFree(d_data);
    return 0;
}
