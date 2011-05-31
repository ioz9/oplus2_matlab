// 
// auto-generated by op2.m on 20-Apr-2011 10:11:42 
//

// user function                                                                  
                                                                                  
#include "update.h"                                                               
                                                                                  
                                                                                  
// x86 kernel function                                                            
                                                                                  
void op_x86_update(                                                               
  float *arg0,                                                                    
  float *arg1,                                                                    
  float *arg2,                                                                    
  float *arg3,                                                                    
  float *arg4,                                                                    
  int   start,                                                                    
  int   finish ) {                                                                
                                                                                  
                                                                                  
  // process set elements                                                         
                                                                                  
  for (int n=start; n<finish; n++) {                                              
                                                                                  
    // user-supplied kernel call                                                  
                                                                                  
    update( arg0+n*4,                                                             
            arg1+n*4,                                                             
            arg2+n*4,                                                             
            arg3+n*1,                                                             
            arg4 );                                                               
  }                                                                               
}                                                                                 
                                                                                  
                                                                                  
// host stub function                                                             
                                                                                  
void op_par_loop_update(char const *name, op_set set,                             
  op_dat arg0, int idx0, op_map map0, int dim0, char const *typ0, op_access acc0, 
  op_dat arg1, int idx1, op_map map1, int dim1, char const *typ1, op_access acc1, 
  op_dat arg2, int idx2, op_map map2, int dim2, char const *typ2, op_access acc2, 
  op_dat arg3, int idx3, op_map map3, int dim3, char const *typ3, op_access acc3, 
  float *arg4h,int idx4, op_map map4, int dim4, char const *typ4, op_access acc4){
                                                                                  
  op_dat_core arg4_dat = {NULL,0,0,(char *)arg4h,NULL,"float","gbl"};             
  op_dat      arg4     = &arg4_dat;                                               
                                                                                  
  if (OP_diags>2) {                                                               
    printf(" kernel routine w/o indirection:  update \n");                        
  }                                                                               
                                                                                  
  // initialise timers                                                            
                                                                                  
  double cpu_t1, cpu_t2, wall_t1, wall_t2;                                        
  op_timers(&cpu_t1, &wall_t1);                                                   
                                                                                  
  // set number of threads                                                        
                                                                                  
#ifdef _OPENMP                                                                    
  int nthreads = omp_get_max_threads( );                                          
#else                                                                             
  int nthreads = 1;                                                               
#endif                                                                            
                                                                                  
  // allocate and initialise arrays for global reduction                          
                                                                                  
  float arg4_l[1+64*64];                                                          
  for (int thr=0; thr<nthreads; thr++)                                            
    for (int d=0; d<1; d++) arg4_l[d+thr*64]=ZERO_float;                          
                                                                                  
  // execute plan                                                                 
                                                                                  
#pragma omp parallel for                                                          
  for (int thr=0; thr<nthreads; thr++) {                                          
    int start  = (set->size* thr   )/nthreads;                                    
    int finish = (set->size*(thr+1))/nthreads;                                    
    op_x86_update( (float *) arg0->dat,                                           
                   (float *) arg1->dat,                                           
                   (float *) arg2->dat,                                           
                   (float *) arg3->dat,                                           
                   arg4_l + thr*64,                                               
                   start, finish );                                               
  }                                                                               
                                                                                  
  // combine reduction data                                                       
                                                                                  
  for (int thr=0; thr<nthreads; thr++)                                            
    for(int d=0; d<1; d++) arg4h[d] += arg4_l[d+thr*64];                          
                                                                                  
  // update kernel record                                                         
                                                                                  
  op_timers(&cpu_t2, &wall_t2);                                                   
  op_timing_realloc(4);                                                           
  OP_kernels[4].name      = name;                                                 
  OP_kernels[4].count    += 1;                                                    
  OP_kernels[4].time     += wall_t2 - wall_t1;                                    
  OP_kernels[4].transfer += (float)set->size * arg0->size;                        
  OP_kernels[4].transfer += (float)set->size * arg1->size;                        
  OP_kernels[4].transfer += (float)set->size * arg2->size * 2.0f;                 
  OP_kernels[4].transfer += (float)set->size * arg3->size;                        
}                                                                                 
                                                                                  
