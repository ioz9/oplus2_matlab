// 
// auto-generated by op2.m on 30-May-2011 21:57:40 
//

// user function                                                        
                                                                        
#include "res.h"                                                        
                                                                        
                                                                        
// x86 kernel function                                                  
                                                                        
void op_x86_res(                                                        
  int    blockIdx,                                                      
  float *ind_arg0, int *ind_arg0_maps,                                  
  float *ind_arg1, int *ind_arg1_maps,                                  
  float *arg0,                                                          
  short *arg1_maps,                                                     
  short *arg2_maps,                                                     
  const float *arg3,                                                    
  int   *ind_arg_sizes,                                                 
  int   *ind_arg_offs,                                                  
  int    block_offset,                                                  
  int   *blkmap,                                                        
  int   *offset,                                                        
  int   *nelems,                                                        
  int   *ncolors,                                                       
  int   *colors) {                                                      
                                                                        
  float arg2_l[1];                                                      
                                                                        
  int   *ind_arg0_map, ind_arg0_size;                        
  int   *ind_arg1_map, ind_arg1_size;                        
  float *ind_arg0_s;                                         
  float *ind_arg1_s;                                         
  int    nelems2, ncolor;                                    
  int    nelem, offset_b;                                    
                                                                        
  char shared[64000];                                        
                                                                        
  if (0==0) {                                                           
                                                                        
    // get sizes and shift pointers and direct-mapped data              
                                                                        
    int blockId = blkmap[blockIdx + block_offset];                      
    nelem    = nelems[blockId];                                         
    offset_b = offset[blockId];                                         
                                                                        
    nelems2  = nelem;                                                   
    ncolor   = ncolors[blockId];                                        
                                                                        
    ind_arg0_size = ind_arg_sizes[0+blockId*2];                         
    ind_arg1_size = ind_arg_sizes[1+blockId*2];                         
                                                                        
    ind_arg0_map = ind_arg0_maps + ind_arg_offs[0+blockId*2];           
    ind_arg1_map = ind_arg1_maps + ind_arg_offs[1+blockId*2];           
                                                                        
    // set shared memory pointers                                       
                                                                        
    int nbytes = 0;                                                     
    ind_arg0_s = (float *) &shared[nbytes];                             
    nbytes    += ROUND_UP(ind_arg0_size*sizeof(float)*1);               
    ind_arg1_s = (float *) &shared[nbytes];                             
  }                                                                     
                                                                        
  __syncthreads(); // make sure all of above completed                  
                                                                        
  // copy indirect datasets into shared memory or zero increment        
                                                                        
  for (int n=0; n<ind_arg0_size; n++)                                   
    for (int d=0; d<1; d++)                                             
      ind_arg0_s[d+n*1] = ind_arg0[d+ind_arg0_map[n]*1];                
                                                                        
  for (int n=0; n<ind_arg1_size; n++)                                   
    for (int d=0; d<1; d++)                                             
      ind_arg1_s[d+n*1] = ZERO_float;                                   
                                                                        
  __syncthreads();                                                      
                                                                        
  // process set elements                                               
                                                                        
  for (int n=0; n<nelems2; n++) {                                       
    int col2 = -1;                                                      
                                                                        
    if (n<nelem) {                                                      
                                                                        
      // initialise local variables                                     
                                                                        
      for (int d=0; d<1; d++)                                           
        arg2_l[d] = ZERO_float;                                         
                                                                        
      // user-supplied kernel call                                      
                                                                        
      res( arg0+(n+offset_b)*1,                                         
           ind_arg0_s+arg1_maps[n+offset_b]*1,                          
           arg2_l,                                                      
           arg3 );                                                      
                                                                        
      col2 = colors[n+offset_b];                                        
    }                                                                   
                                                                        
    // store local variables                                            
                                                                        
    int arg2_map = arg2_maps[n+offset_b];                               
                                                                        
    for (int col=0; col<ncolor; col++) {                                
      if (col2==col) {                                                  
        for (int d=0; d<1; d++)                                         
          ind_arg1_s[d+arg2_map*1] += arg2_l[d];                        
      }                                                                 
      __syncthreads();                                                  
    }                                                                   
                                                                        
  }                                                                     
                                                                        
  // apply pointered write/increment                                    
                                                                        
  for (int n=0; n<ind_arg1_size; n++)                                   
    for (int d=0; d<1; d++)                                             
      ind_arg1[d+ind_arg1_map[n]*1] += ind_arg1_s[d+n*1];               
                                                                        
}                                                                       
                                                                        
                                                                        
// host stub function                                                   
                                                                        
void op_par_loop_res(char const *name, op_set set,                      
  op_arg arg0,                                                          
  op_arg arg1,                                                          
  op_arg arg2,                                                          
  op_arg arg3 ){                                                        
                                                                        
  float *arg3h = (float *)arg3.data;                                    
                                                                        
  int    nargs   = 4;                                                   
  op_arg args[4] = {arg0,arg1,arg2,arg3};                               
                                                                        
  int    ninds   = 2;                                                   
  int    inds[4] = {-1,0,1,-1};                                         
                                                                        
  if (OP_diags>2) {                                                     
    printf(" kernel routine with indirection: res \n");                 
  }                                                                     
                                                                        
  // get plan                                                           
                                                                        
  #ifdef OP_PART_SIZE_0                                                 
    int part_size = OP_PART_SIZE_0;                                     
  #else                                                                 
    int part_size = OP_part_size;                                       
  #endif                                                                
                                                                        
  op_plan *Plan = op_plan_get(name,set,part_size,nargs,args,ninds,inds);
                                                                        
  // initialise timers                                                  
                                                                        
  double cpu_t1, cpu_t2, wall_t1, wall_t2;                              
  op_timers(&cpu_t1, &wall_t1);                                         
                                                                        
  // set number of threads                                              
                                                                        
#ifdef _OPENMP                                                          
  int nthreads = omp_get_max_threads( );                                
#else                                                                   
  int nthreads = 1;                                                     
#endif                                                                  
                                                                        
  // execute plan                                                       
                                                                        
  int block_offset = 0;                                                 
                                                                        
  for (int col=0; col < Plan->ncolors; col++) {                         
    int nblocks = Plan->ncolblk[col];                                   
                                                                        
#pragma omp parallel for                                                
    for (int blockIdx=0; blockIdx<nblocks; blockIdx++)                  
     op_x86_res( blockIdx,                                              
       (float *)arg1.data, Plan->ind_maps[0],                           
       (float *)arg2.data, Plan->ind_maps[1],                           
       (float *)arg0.data,                                              
       Plan->loc_maps[1],                                               
       Plan->loc_maps[2],                                               
       (float *)arg3.data,                                              
       Plan->ind_sizes,                                                 
       Plan->ind_offs,                                                  
       block_offset,                                                    
       Plan->blkmap,                                                    
       Plan->offset,                                                    
       Plan->nelems,                                                    
       Plan->nthrcol,                                                   
       Plan->thrcol);                                                   
                                                                        
    block_offset += nblocks;                                            
  }                                                                     
                                                                        
  // update kernel record                                               
                                                                        
  op_timers(&cpu_t2, &wall_t2);                                         
  op_timing_realloc(0);                                                 
  OP_kernels[0].name      = name;                                       
  OP_kernels[0].count    += 1;                                          
  OP_kernels[0].time     += wall_t2 - wall_t1;                          
  OP_kernels[0].transfer  += Plan->transfer;                            
  OP_kernels[0].transfer2 += Plan->transfer2;                           
}                                                                       
                                                                        
