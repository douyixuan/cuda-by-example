// Surface memory provides read-write access to CUDA arrays —
// unlike textures which are read-only. Surfaces are useful when
// a kernel needs to both read from and write to a 2D grid backed
// by the texture cache hardware.

#include <stdio.h>

const int W = 64;
const int H = 64;

// Write to a surface using `surf2Dwrite`. The surface object
// gives read-write access to the underlying CUDA array.
__global__ void fillSurface(cudaSurfaceObject_t surf, int w, int h) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x < w && y < h) {
        float val = (float)(x + y * w);
        // Note: x offset is in bytes, not elements.
        surf2Dwrite(val, surf, x * sizeof(float), y);
    }
}

// Read back from the surface.
__global__ void readSurface(cudaSurfaceObject_t surf, float *output,
                            int w, int h) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x < w && y < h) {
        float val;
        surf2Dread(&val, surf, x * sizeof(float), y);
        output[y * w + x] = val;
    }
}

int main() {
    cudaChannelFormatDesc desc = cudaCreateChannelDesc<float>();
    cudaArray_t cuArray;
    cudaMallocArray(&cuArray, &desc, W, H, cudaArraySurfaceLoadStore);

    // Create a surface object for read-write access.
    cudaResourceDesc resDesc = {};
    resDesc.resType = cudaResourceTypeArray;
    resDesc.res.array.array = cuArray;

    cudaSurfaceObject_t surf;
    cudaCreateSurfaceObject(&surf, &resDesc);

    dim3 threads(16, 16);
    dim3 blocks((W + 15) / 16, (H + 15) / 16);

    fillSurface<<<blocks, threads>>>(surf, W, H);

    float *d_out;
    cudaMalloc(&d_out, W * H * sizeof(float));
    readSurface<<<blocks, threads>>>(surf, d_out, W, H);

    float h_out[W * H];
    cudaMemcpy(h_out, d_out, W * H * sizeof(float), cudaMemcpyDeviceToHost);

    printf("out[0]=%.0f, out[63]=%.0f, out[4095]=%.0f (expected 0, 63, 4095)\n",
           h_out[0], h_out[63], h_out[W*H-1]);

    cudaDestroySurfaceObject(surf);
    cudaFreeArray(cuArray);
    cudaFree(d_out);
    return 0;
}
