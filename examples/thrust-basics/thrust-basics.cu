// Thrust is CUDA's high-level C++ template library — think STL for GPUs.
// It provides parallel sort, reduce, scan, and transform without
// writing any kernels. Thrust is header-only and ships with the
// CUDA Toolkit.

#include <stdio.h>
#include <thrust/device_vector.h>
#include <thrust/sort.h>
#include <thrust/reduce.h>
#include <thrust/transform.h>
#include <thrust/functional.h>

// A custom functor for `transform`. Thrust functors
// must overload `operator()` with `__host__ __device__`.
struct square {
    __host__ __device__
    float operator()(float x) const { return x * x; }
};

int main() {
    const int N = 1000;

    // `device_vector` manages GPU memory automatically —
    // allocation, copy, and deallocation via RAII.
    thrust::device_vector<float> d_vec(N);

    // Fill with values: 1000, 999, 998, ..., 1
    for (int i = 0; i < N; i++)
        d_vec[i] = (float)(N - i);

    // Sort in-place on the GPU — parallel radix sort under the hood.
    thrust::sort(d_vec.begin(), d_vec.end());
    printf("After sort: first=%.0f, last=%.0f\n",
           (float)d_vec[0], (float)d_vec[N-1]);

    // Reduce (sum) all elements.
    float total = thrust::reduce(d_vec.begin(), d_vec.end(),
                                 0.0f, thrust::plus<float>());
    printf("Sum = %.0f (expected %.0f)\n", total, (float)N*(N+1)/2);

    // Transform: square every element.
    thrust::device_vector<float> d_out(N);
    thrust::transform(d_vec.begin(), d_vec.end(),
                      d_out.begin(), square());
    printf("d_out[0]=%.0f, d_out[9]=%.0f (expected 1, 100)\n",
           (float)d_out[0], (float)d_out[9]);

    return 0;
}
