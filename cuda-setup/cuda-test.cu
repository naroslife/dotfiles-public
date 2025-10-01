/**
 * CUDA Test Program
 *
 * This program tests basic CUDA functionality including:
 * - Device detection and properties
 * - Memory allocation and transfer
 * - Kernel execution
 * - Error handling
 */

#include <stdio.h>
#include <cuda_runtime.h>

#define CUDA_CHECK(call) \
    do { \
        cudaError_t error = call; \
        if (error != cudaSuccess) { \
            fprintf(stderr, "CUDA Error at %s:%d - %s\n", __FILE__, __LINE__, \
                    cudaGetErrorString(error)); \
            return 1; \
        } \
    } while(0)

// Simple kernel that adds two numbers
__global__ void add_kernel(int *a, int *b, int *c) {
    *c = *a + *b;
}

// Kernel that demonstrates thread parallelism
__global__ void hello_kernel(int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        printf("  Thread %d: Hello from GPU!\n", idx);
    }
}

// Vector addition kernel
__global__ void vector_add_kernel(const float *a, const float *b, float *c, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        c[idx] = a[idx] + b[idx];
    }
}

void print_separator() {
    printf("\n========================================\n");
}

int test_device_info() {
    print_separator();
    printf("TEST 1: Device Information\n");
    print_separator();

    int device_count;
    CUDA_CHECK(cudaGetDeviceCount(&device_count));

    printf("Found %d CUDA device(s)\n\n", device_count);

    if (device_count == 0) {
        printf("No CUDA devices found!\n");
        return 1;
    }

    for (int i = 0; i < device_count; i++) {
        cudaDeviceProp prop;
        CUDA_CHECK(cudaGetDeviceProperties(&prop, i));

        printf("Device %d: %s\n", i, prop.name);
        printf("  Compute Capability: %d.%d\n", prop.major, prop.minor);
        printf("  Total Global Memory: %.2f GB\n", prop.totalGlobalMem / 1e9);
        printf("  Multiprocessors: %d\n", prop.multiProcessorCount);
        printf("  Max Threads per Block: %d\n", prop.maxThreadsPerBlock);
        printf("  Max Threads per MP: %d\n", prop.maxThreadsPerMultiProcessor);
        printf("  Warp Size: %d\n", prop.warpSize);
        printf("  Memory Clock Rate: %.2f GHz\n", prop.memoryClockRate / 1e6);
        printf("  Memory Bus Width: %d-bit\n", prop.memoryBusWidth);
        printf("  L2 Cache Size: %.2f MB\n", prop.l2CacheSize / 1e6);

        if (i < device_count - 1) {
            printf("\n");
        }
    }

    printf("\n✓ Device information test passed\n");
    return 0;
}

int test_simple_kernel() {
    print_separator();
    printf("TEST 2: Simple Kernel Execution\n");
    print_separator();

    int a = 5, b = 7;
    int *d_a, *d_b, *d_c;
    int c;

    // Allocate device memory
    printf("Allocating device memory...\n");
    CUDA_CHECK(cudaMalloc(&d_a, sizeof(int)));
    CUDA_CHECK(cudaMalloc(&d_b, sizeof(int)));
    CUDA_CHECK(cudaMalloc(&d_c, sizeof(int)));

    // Copy data to device
    printf("Copying data to device...\n");
    CUDA_CHECK(cudaMemcpy(d_a, &a, sizeof(int), cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_b, &b, sizeof(int), cudaMemcpyHostToDevice));

    // Launch kernel
    printf("Launching kernel: %d + %d = ?\n", a, b);
    add_kernel<<<1, 1>>>(d_a, d_b, d_c);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());

    // Copy result back
    printf("Copying result back to host...\n");
    CUDA_CHECK(cudaMemcpy(&c, d_c, sizeof(int), cudaMemcpyDeviceToHost));

    printf("Result: %d + %d = %d\n", a, b, c);

    // Cleanup
    CUDA_CHECK(cudaFree(d_a));
    CUDA_CHECK(cudaFree(d_b));
    CUDA_CHECK(cudaFree(d_c));

    if (c == a + b) {
        printf("\n✓ Simple kernel test passed\n");
        return 0;
    } else {
        printf("\n✗ Simple kernel test FAILED (expected %d, got %d)\n", a + b, c);
        return 1;
    }
}

int test_parallel_execution() {
    print_separator();
    printf("TEST 3: Parallel Thread Execution\n");
    print_separator();

    int n = 8;
    printf("Launching %d threads to print messages:\n\n", n);

    hello_kernel<<<1, n>>>(n);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());

    printf("\n✓ Parallel execution test passed\n");
    return 0;
}

int test_vector_addition() {
    print_separator();
    printf("TEST 4: Vector Addition\n");
    print_separator();

    const int n = 1024;
    const size_t bytes = n * sizeof(float);

    // Allocate host memory
    printf("Allocating host memory for %d elements...\n", n);
    float *h_a = (float*)malloc(bytes);
    float *h_b = (float*)malloc(bytes);
    float *h_c = (float*)malloc(bytes);

    // Initialize host arrays
    printf("Initializing arrays...\n");
    for (int i = 0; i < n; i++) {
        h_a[i] = (float)i;
        h_b[i] = (float)i * 2.0f;
    }

    // Allocate device memory
    printf("Allocating device memory...\n");
    float *d_a, *d_b, *d_c;
    CUDA_CHECK(cudaMalloc(&d_a, bytes));
    CUDA_CHECK(cudaMalloc(&d_b, bytes));
    CUDA_CHECK(cudaMalloc(&d_c, bytes));

    // Copy data to device
    printf("Copying data to device...\n");
    CUDA_CHECK(cudaMemcpy(d_a, h_a, bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_b, h_b, bytes, cudaMemcpyHostToDevice));

    // Launch kernel
    printf("Launching vector addition kernel...\n");
    int threads_per_block = 256;
    int blocks = (n + threads_per_block - 1) / threads_per_block;
    printf("  Grid: %d blocks x %d threads = %d total threads\n",
           blocks, threads_per_block, blocks * threads_per_block);

    vector_add_kernel<<<blocks, threads_per_block>>>(d_a, d_b, d_c, n);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());

    // Copy result back
    printf("Copying result back to host...\n");
    CUDA_CHECK(cudaMemcpy(h_c, d_c, bytes, cudaMemcpyDeviceToHost));

    // Verify results
    printf("Verifying results...\n");
    int errors = 0;
    for (int i = 0; i < n; i++) {
        float expected = h_a[i] + h_b[i];
        if (h_c[i] != expected) {
            if (errors < 5) {
                printf("  Error at index %d: expected %.2f, got %.2f\n",
                       i, expected, h_c[i]);
            }
            errors++;
        }
    }

    // Cleanup
    cudaFree(d_a);
    cudaFree(d_b);
    cudaFree(d_c);
    free(h_a);
    free(h_b);
    free(h_c);

    if (errors == 0) {
        printf("\n✓ Vector addition test passed (%d elements)\n", n);
        return 0;
    } else {
        printf("\n✗ Vector addition test FAILED (%d errors)\n", errors);
        return 1;
    }
}

int main() {
    printf("\n");
    printf("==========================================\n");
    printf("       CUDA Functionality Test Suite     \n");
    printf("==========================================\n");

    // Get CUDA runtime version
    int runtime_version;
    cudaRuntimeGetVersion(&runtime_version);
    printf("\nCUDA Runtime Version: %d.%d\n",
           runtime_version / 1000, (runtime_version % 100) / 10);

    int driver_version;
    cudaDriverGetVersion(&driver_version);
    printf("CUDA Driver Version: %d.%d\n",
           driver_version / 1000, (driver_version % 100) / 10);

    // Run tests
    int failed = 0;

    if (test_device_info() != 0) failed++;
    if (test_simple_kernel() != 0) failed++;
    if (test_parallel_execution() != 0) failed++;
    if (test_vector_addition() != 0) failed++;

    // Summary
    print_separator();
    printf("TEST SUMMARY\n");
    print_separator();

    if (failed == 0) {
        printf("\n✓ All tests passed!\n");
        printf("\nYour CUDA installation is working correctly.\n\n");
        return 0;
    } else {
        printf("\n✗ %d test(s) failed!\n", failed);
        printf("\nThere are issues with your CUDA installation.\n\n");
        return 1;
    }
}