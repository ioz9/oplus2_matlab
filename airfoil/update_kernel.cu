// 
// auto-generated by op2.m on 11-Feb-2011 11:27:18 
//

// user function                                                                  
                                                                                  
__device__                                                                        
#include "update.h"                                                               
                                                                                  
                                                                                  
// CUDA kernel function                                                           
                                                                                  
__global__ void op_cuda_update(                                                   
  float *arg0,                                                                    
  float *arg1,                                                                    
  float *arg2,                                                                    
  float *arg3,                                                                    
  float *arg4,                                                                    
  int   offset_s,                                                                 
  int   set_size ) {                                                              
                                                                                  
  float arg0_l[4];                                                                
  float arg1_l[4];                                                                
  float arg2_l[4];                                                                
  float arg4_l[1];                                                                
  for (int d=0; d<1; d++) arg4_l[d]=ZERO_float;                                   
  int   tid = threadIdx.x%OP_WARPSIZE;                                            
                                                                                  
  extern __shared__ char shared[];                                                
                                                                                  
  char *arg_s = shared + offset_s*(threadIdx.x/OP_WARPSIZE);                      
                                                                                  
  // process set elements                                                         
                                                                                  
  for (int n=threadIdx.x+blockIdx.x*blockDim.x;                                   
       n<set_size; n+=blockDim.x*gridDim.x) {                                     
                                                                                  
    int offset = n - tid;                                                         
    int nelems = MIN(OP_WARPSIZE,set_size-offset);                                
                                                                                  
    // copy data into shared memory, then into local                              
                                                                                  
    for (int m=0; m<4; m++)                                                       
      ((float *)arg_s)[tid+m*nelems] = arg0[tid+m*nelems+offset*4];               
                                                                                  
    for (int m=0; m<4; m++)                                                       
      arg0_l[m] = ((float *)arg_s)[m+tid*4];                                      
                                                                                  
    for (int m=0; m<4; m++)                                                       
      ((float *)arg_s)[tid+m*nelems] = arg2[tid+m*nelems+offset*4];               
                                                                                  
    for (int m=0; m<4; m++)                                                       
      arg2_l[m] = ((float *)arg_s)[m+tid*4];                                      
                                                                                  
                                                                                  
    // user-supplied kernel call                                                  
                                                                                  
    update( arg0_l,                                                               
            arg1_l,                                                               
            arg2_l,                                                               
            arg3+n,                                                               
            arg4_l );                                                             
                                                                                  
    // copy back into shared memory, then to device                               
                                                                                  
    for (int m=0; m<4; m++)                                                       
      ((float *)arg_s)[m+tid*4] = arg1_l[m];                                      
                                                                                  
    for (int m=0; m<4; m++)                                                       
      arg1[tid+m*nelems+offset*4] = ((float *)arg_s)[tid+m*nelems];               
                                                                                  
    for (int m=0; m<4; m++)                                                       
      ((float *)arg_s)[m+tid*4] = arg2_l[m];                                      
                                                                                  
    for (int m=0; m<4; m++)                                                       
      arg2[tid+m*nelems+offset*4] = ((float *)arg_s)[tid+m*nelems];               
                                                                                  
  }                                                                               
                                                                                  
  // global reductions                                                            
                                                                                  
  for(int d=0; d<1; d++) op_reduction<OP_INC>(&arg4[d+blockIdx.x*1],arg4_l[d]);   
}                                                                                 
                                                                                  
                                                                                  
// host stub function                                                             
                                                                                  
void op_par_loop_update(char const *name, op_set set,                             
  op_dat arg0, int idx0, op_map map0, int dim0, char const *typ0, op_access acc0, 
  op_dat arg1, int idx1, op_map map1, int dim1, char const *typ1, op_access acc1, 
  op_dat arg2, int idx2, op_map map2, int dim2, char const *typ2, op_access acc2, 
  op_dat arg3, int idx3, op_map map3, int dim3, char const *typ3, op_access acc3, 
  float *arg4h,int idx4, op_map map4, int dim4, char const *typ4, op_access acc4){
                                                                                  
  op_dat arg4 = {{0,0,"null"},0,0,0,(char *)arg4h,NULL,"float","gbl"};            
                                                                                  
  if (OP_diags>2) {                                                               
    printf(" kernel routine w/o indirection:  update \n");                        
  }                                                                               
                                                                                  
  // initialise timers                                                            
                                                                                  
  double cpu_t1, cpu_t2, wall_t1, wall_t2;                                        
  timers(&cpu_t1, &wall_t1);                                                      
                                                                                  
  // set CUDA execution parameters                                                
                                                                                  
  int nblocks  = 200;                                                             
//  int nthread  = OP_block_size;                                                 
  int nthread  = 128;                                                             
                                                                                  
  // transfer global reduction data to GPU                                        
                                                                                  
  int maxblocks = nblocks;                                                        
                                                                                  
  int reduct_bytes = 0;                                                           
  int reduct_size  = 0;                                                           
  reduct_bytes += ROUND_UP(maxblocks*1*sizeof(float));                            
  reduct_size   = MAX(reduct_size,sizeof(float));                                 
                                                                                  
  reallocReductArrays(reduct_bytes);                                              
                                                                                  
  reduct_bytes = 0;                                                               
  arg4.dat   = OP_reduct_h + reduct_bytes;                                        
  arg4.dat_d = OP_reduct_d + reduct_bytes;                                        
  for (int b=0; b<maxblocks; b++)                                                 
    for (int d=0; d<1; d++)                                                       
      ((float *)arg4.dat)[d+b*1] = ZERO_float;                                    
  reduct_bytes += ROUND_UP(maxblocks*1*sizeof(float));                            
                                                                                  
  mvReductArraysToDevice(reduct_bytes);                                           
                                                                                  
  // work out shared memory requirements per element                              
                                                                                  
  int nshared = 0;                                                                
  nshared = MAX(nshared,sizeof(float)*4);                                         
  nshared = MAX(nshared,sizeof(float)*4);                                         
  nshared = MAX(nshared,sizeof(float)*4);                                         
                                                                                  
  // execute plan                                                                 
                                                                                  
  int offset_s = nshared*OP_WARPSIZE;                                             
                                                                                  
  nshared = MAX(nshared*nthread,reduct_size*nthread);                             
                                                                                  
  op_cuda_update<<<nblocks,nthread,nshared>>>( (float *) arg0.dat_d,              
                                               (float *) arg1.dat_d,              
                                               (float *) arg2.dat_d,              
                                               (float *) arg3.dat_d,              
                                               (float *) arg4.dat_d,              
                                               offset_s,                          
                                               set.size );                        
                                                                                  
  cutilSafeCall(cudaThreadSynchronize());                                         
  cutilCheckMsg("op_cuda_update execution failed\n");                             
                                                                                  
  // transfer global reduction data back to CPU                                   
                                                                                  
  mvReductArraysToHost(reduct_bytes);                                             
                                                                                  
  for (int b=0; b<maxblocks; b++)                                                 
    for (int d=0; d<1; d++)                                                       
      arg4h[d] = arg4h[d] + ((float *)arg4.dat)[d+b*1];                           
                                                                                  
  // update kernel record                                                         
                                                                                  
  timers(&cpu_t2, &wall_t2);                                                      
  OP_kernels[4].name      = name;                                                 
  OP_kernels[4].count    += 1;                                                    
  OP_kernels[4].time     += wall_t2 - wall_t1;                                    
  OP_kernels[4].transfer += (float)set.size * arg0.size;                          
  OP_kernels[4].transfer += (float)set.size * arg1.size;                          
  OP_kernels[4].transfer += (float)set.size * arg2.size * 2.0f;                   
  OP_kernels[4].transfer += (float)set.size * arg3.size;                          
}                                                                                 
                                                                                  
