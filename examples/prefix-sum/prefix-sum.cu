// Prefix sum (scan) computes running totals: given [1,2,3,4],
// inclusive scan produces [1,3,6,10]. It is a fundamental building
// block for stream compaction, radix sort, and histogram equalization.

#include <stdio.h>

const int N = 256;

// Hillis-Steele inclusive scan within a single block.
// Work-efficient for block-sized arrays (≤ 1024 elements).
__global__ void inclusiveScan(int *data, int n) {
    extern __shared__ int temp[];

    int tid = threadIdx.x;
    temp[tid] = (tid < n) ? data[tid] : 0;
    __syncthreads();

    // Each step, thread tid adds the element `stride` positions back.
    // After log2(n) steps, every position holds its prefix sum.
    for (int stride = 1; stride < n; stride *= 2) {
        int val = (tid >= stride) ? temp[tid - stride] : 0;
        __syncthreads();
        temp[tid] += val;
        __syncthreads();
    }

    if (tid < n) data[tid] = temp[tid];
}

int main() {
    int h_data[N];
    for (int i = 0; i < N; i++) h_data[i] = 1;

    int *d_data;
    cudaMalloc(&d_data, N * sizeof(int));
    cudaMemcpy(d_data, h_data, N * sizeof(int), cudaMemcpyHostToDevice);

    inclusiveScan<<<1, N, N * sizeof(int)>>>(d_data, N);
    cudaMemcpy(h_data, d_data, N * sizeof(int), cudaMemcpyDeviceToHost);

    // With all-ones input, scan[i] = i+1.
    printf("scan[0]=%d, scan[127]=%d, scan[255]=%d (expected 1,128,256)\n",
           h_data[0], h_data[127], h_data[255]);

    cudaFree(d_data);
    return 0;
}
