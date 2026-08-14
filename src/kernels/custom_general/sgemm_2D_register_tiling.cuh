// preprocessor directive used in header files to ensure the file is included only once during a single compilation
#pragma once

#include <iostream>
#include <stdlib.h>
#include <cuda_runtime.h>
#include <cmath>


template <
    const uint TILE_SIZE_M, const uint TILE_SIZE_N, const uint TILE_SIZE_K, 
    const uint ROWS_PER_THREAD,
    const uint COLS_PER_THREAD
>
__global__ void sgemm_2D_register_tiling(
    const float* __restrict__ A, const float* __restrict__ B, float* __restrict__ C,
    int M, int N, int K, float alpha, float beta
) {
    __shared__ float sharedA[TILE_SIZE_M * TILE_SIZE_N];
    __shared__ float sharedB[TILE_SIZE_N * TILE_SIZE_K];

    const uint block_row = blockIdx.y;
    const uint block_col = blockIdx.x;

    const uint tid_Cy = threadIdx.x / (TILE_SIZE_K / COLS_PER_THREAD);
    const uint tid_Cx = threadIdx.x / (TILE_SIZE_K / COLS_PER_THREAD);

    A += block_row * TILE_SIZE_M * N;
    B += TILE_SIZE_K * block_col;
    C += block_row * TILE_SIZE_M * K + block_col * TILE_SIZE_K;

    // Assume each thread only moves one element/byte at a time when moving data from GMEM to SMEM
    const uint smem_ty_A = threadIdx.x / TILE_SIZE_N;
    const uint smem_tx_A = threadIdx.x % TILE_SIZE_N;

    const uint smem_ty_B = threadIdx.x / TILE_SIZE_K;
    const uint smem_tx_B = threadIdx.x % TILE_SIZE_K;

    const uint num_elems_tile_C = TILE_SIZE_M * TILE_SIZE_K;
    const uint num_threads_per_block = num_elems_tile_C / (ROWS_PER_THREAD * COLS_PER_THREAD);

    const uint stride_smem_A = num_threads_per_block / TILE_SIZE_N;
    const uint stride_smem_B = num_threads_per_block / TILE_SIZE_K; 

    const uint num_tiles = CEIL_DIV(N, TILE_SIZE_N);
    float thread_results[ROWS_PER_THREAD * COLS_PER_THREAD] = {0.0f};
    float reg_m[ROWS_PER_THREAD] = {0.0f};
    float reg_n[COLS_PER_THREAD] = {0.0f};

    for (int t = 0; t < num_tiles; t++){
        // Moving data from GMEM to SMEM
        for (int load_offset = 0; load_offset < TILE_SIZE_M; load_offset += stride_smem_A){
            sharedA[(smem_ty_A + load_offset) * TILE_SIZE_N + smem_tx_A] = \
                A[(smem_ty_A + load_offset) * N + smem_tx_A];
        }
        for (int load_offset = 0; load_offset < TILE_SIZE_N; load_offset += stride_smem_B) {
            sharedB[(smem_ty_B + load_offset) * TILE_SIZE_K + smem_tx_B] = \
                B[(smem_ty_B + load_offset) * K + smem_tx_B];
        }
        __syncthreads();


        for (int i = 0; i < TILE_SIZE_N; i++){
            for (int row = 0; row < ROWS_PER_THREAD; row ++)
                reg_m[row] = shared_A[((tid_Cy * ROWS_PER_THREAD  + row) * TILE_SIZE_N) + i];
            
            for (int col = 0; col < COLS_PER_THREADS; col++)
                reg_n[col] = shared_B[i * TILE_SIZE_K + (tid_Cx * COLS_PER_THREAD + col)];
            
            for (int m = 0; m < COLS_PER_THREAD; m++){
                for (int k = 0; k < ROWS_PER_THREAD; k++){
                    thread_results[m * COLS_PER_THREAD + k] += reg_m[m] * reg_k[k];
                }
            }
        }
        __syncthreads();

        A += TILE_SIZE_N;
        B += TILE_SIZE_N * K;
    }
    
    for (uint row = 0; row < ROWS_PER_THREAD; row ++) {
        for (uint col = 0; col < COLS_PER_THREAD; col++){
            uint global_row_id; 
        }
    }
}