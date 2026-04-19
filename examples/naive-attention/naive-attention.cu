// Naive attention computes Attention(Q,K,V) = softmax(Q·Kᵀ/√d)·V.
// This three-step implementation materializes the full attention matrix,
// which is O(seq²) memory. Use small dimensions (seq=8, d=4) to keep
// the example self-contained without cuBLAS.
//
// Compile: nvcc -arch=sm_80 naive-attention.cu -o naive-attention

#include <stdio.h>
#include <math.h>

const int SEQ = 8;
const int D   = 4;

// Step 1: scores[i][j] = dot(Q[i], K[j]) / sqrt(D)
__global__ void dotScores(const float *Q, const float *K, float *scores, int seq, int d) {
    int i = blockIdx.x, j = threadIdx.x;
    if (j >= seq) return;
    float s = 0;
    for (int k = 0; k < d; k++) s += Q[i * d + k] * K[j * d + k];
    scores[i * seq + j] = s / sqrtf((float)d);
}

// Step 2: softmax each row of scores in-place.
__global__ void softmaxRows(float *scores, int seq) {
    int i = blockIdx.x;
    float mx = -1e38f;
    for (int j = 0; j < seq; j++) mx = fmaxf(mx, scores[i * seq + j]);
    float sum = 0;
    for (int j = 0; j < seq; j++) { scores[i * seq + j] = expf(scores[i * seq + j] - mx); sum += scores[i * seq + j]; }
    for (int j = 0; j < seq; j++) scores[i * seq + j] /= sum;
}

// Step 3: out[i] = sum_j scores[i][j] * V[j]
__global__ void weightedSum(const float *scores, const float *V, float *out, int seq, int d) {
    int i = blockIdx.x, k = threadIdx.x;
    if (k >= d) return;
    float s = 0;
    for (int j = 0; j < seq; j++) s += scores[i * seq + j] * V[j * d + k];
    out[i * d + k] = s;
}

int main() {
    float h_Q[SEQ*D], h_K[SEQ*D], h_V[SEQ*D], h_out[SEQ*D];
    for (int i = 0; i < SEQ*D; i++) { h_Q[i] = (float)i / (SEQ*D); h_K[i] = h_Q[i]; h_V[i] = 1.0f; }

    float *d_Q, *d_K, *d_V, *d_scores, *d_out;
    cudaMalloc(&d_Q,      SEQ*D   * sizeof(float));
    cudaMalloc(&d_K,      SEQ*D   * sizeof(float));
    cudaMalloc(&d_V,      SEQ*D   * sizeof(float));
    cudaMalloc(&d_scores, SEQ*SEQ * sizeof(float));
    cudaMalloc(&d_out,    SEQ*D   * sizeof(float));
    cudaMemcpy(d_Q, h_Q, SEQ*D * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(d_K, h_K, SEQ*D * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(d_V, h_V, SEQ*D * sizeof(float), cudaMemcpyHostToDevice);

    dotScores<<<SEQ, SEQ>>>(d_Q, d_K, d_scores, SEQ, D);
    softmaxRows<<<SEQ, 1>>>(d_scores, SEQ);
    weightedSum<<<SEQ, D>>>(d_scores, d_V, d_out, SEQ, D);

    cudaMemcpy(h_out, d_out, SEQ*D * sizeof(float), cudaMemcpyDeviceToHost);
    // V is all-ones, so output should be all-ones (weighted sum of ones = 1).
    printf("out[0][0]=%.4f  out[7][3]=%.4f (expected 1.0)\n", h_out[0], h_out[SEQ*D-1]);

    cudaFree(d_Q); cudaFree(d_K); cudaFree(d_V); cudaFree(d_scores); cudaFree(d_out);
    return 0;
}
