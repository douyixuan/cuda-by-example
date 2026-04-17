// cuRAND generates random numbers on the GPU — millions of values
// in parallel, far faster than CPU-based RNGs. Essential for
// Monte Carlo simulations, stochastic algorithms, and data augmentation.
//
// Compile with: nvcc curand-basics.cu -lcurand

#include <stdio.h>
#include <curand.h>

int main() {
    const int N = 1 << 20;

    float *d_data;
    cudaMalloc(&d_data, N * sizeof(float));

    // Create a generator — XORWOW is the default pseudo-RNG.
    // Other options: MTGP32, Philox, Sobol (quasi-random).
    curandGenerator_t gen;
    curandCreateGenerator(&gen, CURAND_RNG_PSEUDO_DEFAULT);
    curandSetPseudoRandomGeneratorSeed(gen, 42);

    // Generate N uniform floats in [0, 1) — directly on the GPU.
    // No host memory or copying needed.
    curandGenerateUniform(gen, d_data, N);

    // Copy a few values back to verify.
    float h_sample[5];
    cudaMemcpy(h_sample, d_data, 5 * sizeof(float), cudaMemcpyDeviceToHost);
    printf("Uniform samples: %.4f %.4f %.4f %.4f %.4f\n",
           h_sample[0], h_sample[1], h_sample[2], h_sample[3], h_sample[4]);

    // Generate normal distribution with mean=0, stddev=1.
    curandGenerateNormal(gen, d_data, N, 0.0f, 1.0f);
    cudaMemcpy(h_sample, d_data, 5 * sizeof(float), cudaMemcpyDeviceToHost);
    printf("Normal samples:  %.4f %.4f %.4f %.4f %.4f\n",
           h_sample[0], h_sample[1], h_sample[2], h_sample[3], h_sample[4]);

    // Compute mean on CPU to verify distribution.
    float *h_all = new float[N];
    cudaMemcpy(h_all, d_data, N * sizeof(float), cudaMemcpyDeviceToHost);
    double sum = 0;
    for (int i = 0; i < N; i++) sum += h_all[i];
    printf("Normal mean = %.4f (expected ~0.0)\n", sum / N);

    delete[] h_all;
    curandDestroyGenerator(gen);
    cudaFree(d_data);
    return 0;
}
