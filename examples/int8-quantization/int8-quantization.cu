// INT8 quantization maps float32 weights to int8 for inference.
// Each value is scaled to [-127, 127], stored as int8, then dequantized
// back to float32 for computation. LLM.int8() uses this for 8-bit inference.
//
// Source: [github.com/TimDettmers/bitsandbytes](https://github.com/TimDettmers/bitsandbytes) — Int8 CUDA kernels
// Compile: nvcc -arch=sm_80 int8-quantization.cu -o int8-quantization

#include <stdio.h>
#include <math.h>

const int N = 1024;

// Quantize: float32 → int8 using per-tensor absmax scaling.
__global__ void quantize(const float *input, int8_t *output, float scale, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        float scaled = input[i] / scale * 127.0f;
        // Clamp to [-127, 127] and round to nearest integer.
        output[i] = (int8_t)fmaxf(-127.0f, fminf(127.0f, rintf(scaled)));
    }
}

// Dequantize: int8 → float32.
__global__ void dequantize(const int8_t *input, float *output, float scale, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) output[i] = (float)input[i] / 127.0f * scale;
}

int main() {
    float h_in[N], h_out[N];
    for (int i = 0; i < N; i++) h_in[i] = sinf((float)i / N * 6.28f);

    // Scale = absmax of the tensor.
    float absmax = 0;
    for (int i = 0; i < N; i++) absmax = fmaxf(absmax, fabsf(h_in[i]));

    float   *d_in, *d_out;
    int8_t  *d_q;
    cudaMalloc(&d_in,  N * sizeof(float));
    cudaMalloc(&d_q,   N * sizeof(int8_t));
    cudaMalloc(&d_out, N * sizeof(float));
    cudaMemcpy(d_in, h_in, N * sizeof(float), cudaMemcpyHostToDevice);

    quantize<<<4, 256>>>(d_in, d_q, absmax, N);
    dequantize<<<4, 256>>>(d_q, d_out, absmax, N);
    cudaMemcpy(h_out, d_out, N * sizeof(float), cudaMemcpyDeviceToHost);

    // Quantization error should be < 1/127 ≈ 0.008.
    float max_err = 0;
    for (int i = 0; i < N; i++) max_err = fmaxf(max_err, fabsf(h_in[i] - h_out[i]));
    printf("absmax=%.4f  max_quant_error=%.6f  in[0]=%.4f  out[0]=%.4f\n",
           absmax, max_err, h_in[0], h_out[0]);

    cudaFree(d_in); cudaFree(d_q); cudaFree(d_out);
    return 0;
}
