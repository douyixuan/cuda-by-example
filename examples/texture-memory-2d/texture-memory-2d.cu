// 2D texture memory with interpolation — the GPU performs bilinear
// filtering in hardware for free. This is why textures are essential
// for image processing: you get sub-pixel sampling without writing
// any interpolation code.

#include <stdio.h>

const int W = 64;
const int H = 64;

// Sample the texture at (x, y) with hardware interpolation.
__global__ void resample(cudaTextureObject_t tex, float *output,
                         int outW, int outH, float scaleX, float scaleY) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x < outW && y < outH) {
        // `tex2D<float>` with normalized coordinates + linear filtering
        // performs bilinear interpolation entirely in hardware.
        float u = (x + 0.5f) * scaleX;
        float v = (y + 0.5f) * scaleY;
        output[y * outW + x] = tex2D<float>(tex, u, v);
    }
}

int main() {
    // Create a 64×64 source image.
    float h_data[W * H];
    for (int y = 0; y < H; y++)
        for (int x = 0; x < W; x++)
            h_data[y * W + x] = (float)(x + y);

    // Allocate a CUDA array — the native format for 2D textures.
    cudaChannelFormatDesc channelDesc = cudaCreateChannelDesc<float>();
    cudaArray_t cuArray;
    cudaMallocArray(&cuArray, &channelDesc, W, H);
    cudaMemcpy2DToArray(cuArray, 0, 0, h_data, W * sizeof(float),
                        W * sizeof(float), H, cudaMemcpyHostToDevice);

    // Configure the texture for normalized coordinates and linear filtering.
    cudaResourceDesc resDesc = {};
    resDesc.resType = cudaResourceTypeArray;
    resDesc.res.array.array = cuArray;

    cudaTextureDesc texDesc = {};
    texDesc.normalizedCoords = 0;
    texDesc.filterMode = cudaFilterModeLinear;
    texDesc.addressMode[0] = cudaAddressModeClamp;
    texDesc.addressMode[1] = cudaAddressModeClamp;
    texDesc.readMode = cudaReadModeElementType;

    cudaTextureObject_t tex;
    cudaCreateTextureObject(&tex, &resDesc, &texDesc, NULL);

    // Resample to 32×32 (downscale by 2x).
    const int outW = 32, outH = 32;
    float *d_out;
    cudaMalloc(&d_out, outW * outH * sizeof(float));

    dim3 threads(16, 16);
    dim3 blocks((outW + 15) / 16, (outH + 15) / 16);
    float scaleX = (float)W / outW;
    float scaleY = (float)H / outH;
    resample<<<blocks, threads>>>(tex, d_out, outW, outH, scaleX, scaleY);

    float h_out[outW * outH];
    cudaMemcpy(h_out, d_out, outW * outH * sizeof(float), cudaMemcpyDeviceToHost);

    printf("out[0][0]=%.1f, out[16][16]=%.1f\n", h_out[0], h_out[16*outW+16]);

    cudaDestroyTextureObject(tex);
    cudaFreeArray(cuArray);
    cudaFree(d_out);
    return 0;
}
