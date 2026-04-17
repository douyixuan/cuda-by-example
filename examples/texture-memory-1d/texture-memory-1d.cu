// Texture memory provides hardware-accelerated caching optimized for
// spatial locality. Unlike global memory, it caches in 2D patterns
// and supports free interpolation and boundary clamping.
// This example shows basic 1D texture usage with the texture object API.

#include <stdio.h>

const int N = 256;

// Read from the texture object — the hardware fetches through
// a dedicated read-only cache separate from L1/L2.
__global__ void transform(cudaTextureObject_t tex, float *output, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        // `tex1Dfetch` reads element i from the 1D texture.
        // This goes through the texture cache, not the L1.
        output[i] = tex1Dfetch<float>(tex, i) * 2.0f;
    }
}

int main() {
    float h_data[N];
    for (int i = 0; i < N; i++) h_data[i] = (float)i;

    // Allocate and copy to device memory that will back the texture.
    float *d_data;
    cudaMalloc(&d_data, N * sizeof(float));
    cudaMemcpy(d_data, h_data, N * sizeof(float), cudaMemcpyHostToDevice);

    // Create a texture object — the modern API (replaces texture references).
    cudaResourceDesc resDesc = {};
    resDesc.resType = cudaResourceTypeLinear;
    resDesc.res.linear.devPtr = d_data;
    resDesc.res.linear.desc = cudaCreateChannelDesc<float>();
    resDesc.res.linear.sizeInBytes = N * sizeof(float);

    cudaTextureDesc texDesc = {};
    texDesc.readMode = cudaReadModeElementType;

    cudaTextureObject_t tex;
    cudaCreateTextureObject(&tex, &resDesc, &texDesc, NULL);

    float *d_out;
    cudaMalloc(&d_out, N * sizeof(float));

    transform<<<(N+63)/64, 64>>>(tex, d_out, N);

    float h_out[N];
    cudaMemcpy(h_out, d_out, N * sizeof(float), cudaMemcpyDeviceToHost);

    printf("h_out[0]=%.0f, h_out[100]=%.0f (expected 0, 200)\n",
           h_out[0], h_out[100]);

    cudaDestroyTextureObject(tex);
    cudaFree(d_data);
    cudaFree(d_out);
    return 0;
}
