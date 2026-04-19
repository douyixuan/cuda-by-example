// Flash Attention avoids materializing the full seq×seq attention matrix
// by processing Q, K, V in tiles that fit in shared memory. Each tile
// updates the output using online softmax (running max + sum), so the
// final result is numerically identical to naive attention.
//
// This is a conceptual demonstration: single head, seq=16, d=8.
// For production use, see Tri Dao's FlashAttention (github.com/Dao-AILab/flash-attention).
//
// Compile: nvcc -arch=sm_80 flash-attention-tiling.cu -o flash-attention-tiling

#include <stdio.h>
#include <math.h>

const int SEQ  = 16;
const int D    = 8;
const int TILE = 4;  // tile size for K/V blocks

// One block per query row. Iterates over K/V tiles, updating output
// with online softmax to avoid storing the full attention matrix.
__global__ void flashAttentionTile(
    const float *Q, const float *K, const float *V, float *out,
    int seq, int d, int tile)
{
    int qi = blockIdx.x;  // which query row this block handles

    __shared__ float sK[TILE * 8];  // K tile (tile × d, d≤8)
    __shared__ float sV[TILE * 8];  // V tile

    // Accumulator for the output row, running max, and running sum.
    float acc[8] = {};
    float m_prev = -1e38f, l_prev = 0.0f;

    for (int t = 0; t < seq / tile; t++) {
        // Load K and V tiles into shared memory.
        for (int j = threadIdx.x; j < tile * d; j += blockDim.x) {
            int row = t * tile + j / d, col = j % d;
            sK[j] = K[row * d + col];
            sV[j] = V[row * d + col];
        }
        __syncthreads();

        // Compute scores for this tile: s[j] = dot(Q[qi], K[t*tile+j]) / sqrt(d)
        float s[TILE];
        for (int j = 0; j < tile; j++) {
            s[j] = 0;
            for (int k = 0; k < d; k++) s[j] += Q[qi * d + k] * sK[j * d + k];
            s[j] /= sqrtf((float)d);
        }

        // Online softmax update: find tile max, update running max and sum.
        float m_tile = s[0];
        for (int j = 1; j < tile; j++) m_tile = fmaxf(m_tile, s[j]);

        float m_new = fmaxf(m_prev, m_tile);
        float l_new = expf(m_prev - m_new) * l_prev;
        for (int j = 0; j < tile; j++) l_new += expf(s[j] - m_new);

        // Rescale accumulator and add new tile's contribution.
        float scale = expf(m_prev - m_new);
        for (int k = 0; k < d; k++) {
            acc[k] *= scale * l_prev;
            for (int j = 0; j < tile; j++)
                acc[k] += expf(s[j] - m_new) * sV[j * d + k];
            acc[k] /= l_new;
        }

        m_prev = m_new;
        l_prev = l_new;
        __syncthreads();
    }

    if (threadIdx.x == 0)
        for (int k = 0; k < d; k++) out[qi * d + k] = acc[k];
}

int main() {
    float h_Q[SEQ*D], h_K[SEQ*D], h_V[SEQ*D], h_out[SEQ*D];
    for (int i = 0; i < SEQ*D; i++) { h_Q[i] = (float)i/(SEQ*D); h_K[i] = h_Q[i]; h_V[i] = 1.0f; }

    float *d_Q, *d_K, *d_V, *d_out;
    cudaMalloc(&d_Q,   SEQ*D * sizeof(float));
    cudaMalloc(&d_K,   SEQ*D * sizeof(float));
    cudaMalloc(&d_V,   SEQ*D * sizeof(float));
    cudaMalloc(&d_out, SEQ*D * sizeof(float));
    cudaMemcpy(d_Q, h_Q, SEQ*D * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(d_K, h_K, SEQ*D * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(d_V, h_V, SEQ*D * sizeof(float), cudaMemcpyHostToDevice);

    flashAttentionTile<<<SEQ, 1>>>(d_Q, d_K, d_V, d_out, SEQ, D, TILE);
    cudaMemcpy(h_out, d_out, SEQ*D * sizeof(float), cudaMemcpyDeviceToHost);

    // V is all-ones → output should be all-ones.
    printf("out[0][0]=%.4f  out[15][7]=%.4f (expected 1.0)\n", h_out[0], h_out[SEQ*D-1]);

    cudaFree(d_Q); cudaFree(d_K); cudaFree(d_V); cudaFree(d_out);
    return 0;
}
