// Many problems are naturally 2-dimensional: images, matrices, grids.
// CUDA supports 2D thread and block indexing natively via `dim3`.

#include <stdio.h>

// Each thread prints its 2D coordinates and the flat row-major index.
__global__ void show2DIndex() {
    // 2D thread coordinates within the block.
    int tx = threadIdx.x;
    int ty = threadIdx.y;

    // 2D block coordinates within the grid.
    int bx = blockIdx.x;
    int by = blockIdx.y;

    // Flat global index using row-major order.
    // This is how you'd index into a 2D array stored as a 1D buffer.
    int globalX = bx * blockDim.x + tx;
    int globalY = by * blockDim.y + ty;
    int width   = gridDim.x * blockDim.x;
    int flatIdx = globalY * width + globalX;

    printf("block(%d,%d) thread(%d,%d) -> global(%d,%d) flat=%d\n",
           bx, by, tx, ty, globalX, globalY, flatIdx);
}

int main() {
    // `dim3` lets you specify 2D (or 3D) dimensions.
    // Here: 2x2 grid of blocks, each block is 3x3 threads.
    // Total threads: 6x6 = 36.
    dim3 blocks(2, 2);
    dim3 threads(3, 3);
    show2DIndex<<<blocks, threads>>>();
    cudaDeviceSynchronize();
    return 0;
}
