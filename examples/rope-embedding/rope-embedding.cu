// RoPE (Rotary Position Embedding) encodes position by rotating pairs of
// query/key dimensions. Thread i handles the pair (2i, 2i+1), applying
// a rotation by angle pos * theta^(-2i/d). Used in LLaMA, Mistral, GPT-NeoX.
//
// Source: [github.com/meta-llama/llama](https://github.com/meta-llama/llama/blob/main/llama/model.py) — apply\_rotary\_emb
// Compile: nvcc -arch=sm_80 rope-embedding.cu -o rope-embedding

#include <stdio.h>
#include <math.h>

const int SEQ  = 8;   // sequence length
const int DIM  = 64;  // head dimension (must be even)

// Each thread rotates one pair of dimensions for one token.
// Thread layout: blockIdx.x = token position, threadIdx.x = pair index.
__global__ void ropeEmbedding(float *q, int seq, int dim) {
    int pos  = blockIdx.x;           // token position
    int pair = threadIdx.x;          // dimension pair index
    if (pair >= dim / 2) return;

    // Rotation angle: theta_i = pos / (10000^(2i/dim))
    float theta = (float)pos / powf(10000.0f, 2.0f * pair / dim);
    float cos_t = cosf(theta);
    float sin_t = sinf(theta);

    int base = pos * dim + pair * 2;
    float x0 = q[base];
    float x1 = q[base + 1];

    // Rotate: [x0, x1] → [x0*cos - x1*sin, x0*sin + x1*cos]
    q[base]     = x0 * cos_t - x1 * sin_t;
    q[base + 1] = x0 * sin_t + x1 * cos_t;
}

int main() {
    const int total = SEQ * DIM;
    float h_q[total];
    for (int i = 0; i < total; i++) h_q[i] = 1.0f;

    float *d_q;
    cudaMalloc(&d_q, total * sizeof(float));
    cudaMemcpy(d_q, h_q, total * sizeof(float), cudaMemcpyHostToDevice);

    // One block per token, DIM/2 threads per block.
    ropeEmbedding<<<SEQ, DIM / 2>>>(d_q, SEQ, DIM);
    cudaMemcpy(h_q, d_q, total * sizeof(float), cudaMemcpyDeviceToHost);

    // Position 0: theta=0, rotation is identity → (1,1).
    // Position 1: pair 0 rotated by theta=1/10000^0=1 rad.
    printf("pos=0 pair=0: (%.4f, %.4f)  pos=1 pair=0: (%.4f, %.4f)\n",
           h_q[0], h_q[1], h_q[DIM], h_q[DIM+1]);

    cudaFree(d_q);
    return 0;
}
