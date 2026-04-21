// Flash Attention avoids materializing the full seq×seq attention matrix
// by processing K, V in tiles that fit in shared memory. Each tile updates
// the output using online softmax (running max + sum), giving a result
// numerically identical to naive attention with O(seq·d) memory.
//
// Conceptual demo: single head, seq=16, d=8. For production, see Tri Dao's
// reference: github.com/Dao-AILab/flash-attention
//
// Source: [github.com/Dao-AILab/flash-attention](https://github.com/Dao-AILab/flash-attention) — flash\_fwd\_kernel.h
// Compile: nvcc -arch=sm_80 flash-attention-tiling.cu -o flash-attention-tiling

#include <stdio.h>
#include <math.h>

const int SEQ = 16, D = 8, TILE = 4;

// One block per query row. Iterates over K/V tiles, updating the output
// row with online softmax so the full attention matrix is never stored.
__global__ void flashAttentionTile(const float *Q, const float *K,
                                   const float *V, float *out) {
    int qi = blockIdx.x;
    __shared__ float sK[TILE * D], sV[TILE * D];
    float acc[D] = {}, m_prev = -1e38f, l_prev = 0.0f;

    for (int t = 0; t < SEQ / TILE; t++) {
        // Load K and V tiles into shared memory.
        for (int j = threadIdx.x; j < TILE * D; j += blockDim.x) {
            int row = t * TILE + j / D;
            sK[j] = K[row * D + j % D];
            sV[j] = V[row * D + j % D];
        }
        __syncthreads();

        // Scores for this tile: s[j] = dot(Q[qi], K[t*TILE+j]) / sqrt(d).
        float s[TILE], m_tile = -1e38f;
        for (int j = 0; j < TILE; j++) {
            s[j] = 0;
            for (int k = 0; k < D; k++) s[j] += Q[qi * D + k] * sK[j * D + k];
            s[j] /= sqrtf((float)D);
            m_tile = fmaxf(m_tile, s[j]);
        }

        // Online softmax update: new running max, sum, and rescaled accum.
        float m_new = fmaxf(m_prev, m_tile);
        float l_new = expf(m_prev - m_new) * l_prev;
        for (int j = 0; j < TILE; j++) l_new += expf(s[j] - m_new);

        float scale = expf(m_prev - m_new);
        for (int k = 0; k < D; k++) {
            acc[k] *= scale * l_prev;
            for (int j = 0; j < TILE; j++)
                acc[k] += expf(s[j] - m_new) * sV[j * D + k];
            acc[k] /= l_new;
        }
        m_prev = m_new; l_prev = l_new;
        __syncthreads();
    }

    if (threadIdx.x == 0)
        for (int k = 0; k < D; k++) out[qi * D + k] = acc[k];
}

int main() {
    float h_Q[SEQ*D], h_K[SEQ*D], h_V[SEQ*D], h_out[SEQ*D];
    for (int i = 0; i < SEQ*D; i++) { h_Q[i] = (float)i/(SEQ*D); h_K[i] = h_Q[i]; h_V[i] = 1.0f; }

    float *d_Q, *d_K, *d_V, *d_out;
    size_t sz = SEQ * D * sizeof(float);
    cudaMalloc(&d_Q, sz); cudaMalloc(&d_K, sz); cudaMalloc(&d_V, sz); cudaMalloc(&d_out, sz);
    cudaMemcpy(d_Q, h_Q, sz, cudaMemcpyHostToDevice);
    cudaMemcpy(d_K, h_K, sz, cudaMemcpyHostToDevice);
    cudaMemcpy(d_V, h_V, sz, cudaMemcpyHostToDevice);
    flashAttentionTile<<<SEQ, 1>>>(d_Q, d_K, d_V, d_out);
    cudaMemcpy(h_out, d_out, sz, cudaMemcpyDeviceToHost);
    // V is all-ones → output should be all-ones.
    printf("out[0][0]=%.4f  out[15][7]=%.4f (expected 1.0)\n", h_out[0], h_out[SEQ*D-1]);

    cudaFree(d_Q); cudaFree(d_K); cudaFree(d_V); cudaFree(d_out);
    return 0;
}
