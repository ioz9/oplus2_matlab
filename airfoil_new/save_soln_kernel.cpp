// 
// auto-generated by op2.m on 31-Oct-2010 14:33:26 
//

// user function                                                                  
                                                                                  
#include "save_soln.h"                                                            
                                                                                  
                                                                                  
// x86 kernel function                                                            
                                                                                  
void op_x86_save_soln(                                                            
  float *arg0,                                                                    
  float *arg1,                                                                    
  int   begin,                                                                    
  int   finish ) {                                                                
                                                                                  
                                                                                  
  // process set elements                                                         
                                                                                  
  for (int n=begin; n<finish; n++) {                                              
                                                                                  
      // user-supplied kernel call                                                
                                                                                  
      save_soln( arg0+n*4,                                                        
                 arg1+n*4 );                                                      
  }                                                                               
}                                                                                 
                                                                                  
                                                                                  
// host stub function                                                             
                                                                                  
void op_par_loop_save_soln(char const *name, op_set set,                          
  op_dat arg0, int idx0, op_ptr ptr0, int dim0, char const *typ0, op_access acc0, 
  op_dat arg1, int idx1, op_ptr ptr1, int dim1, char const *typ1, op_access acc1){
                                                                                  
                                                                                  
  if (OP_diags>2) {                                                               
    printf(" kernel routine w/o indirection:  save_soln \n");                     
  }                                                                               
                                                                                  
  // initialise timers                                                            
                                                                                  
  double cpu_t1, cpu_t2, wall_t1, wall_t2;                                        
  timers(&cpu_t1, &wall_t1);                                                      
                                                                                  
  // set number of threads                                                        
                                                                                  
#ifdef _OPENMP                                                                    
  int nthreads = omp_get_max_threads( );                                          
#else                                                                             
  int nthreads = 1;                                                               
#endif                                                                            
                                                                                  
  // execute plan                                                                 
                                                                                  
  int nblocks = 100;                                                              
  int nthread = OP_block_size;                                                    
#pragma omp parallel for                                                          
  for (int thr=0; thr<nthreads; thr++) {                                          
    int start  = (set.size* thr   )/nthreads;                                     
    int finish = (set.size*(thr+1))/nthreads;                                     
    op_x86_save_soln( (float *) arg0.dat,                                         
                      (float *) arg1.dat,                                         
                      start, finish );                                            
  }                                                                               
                                                                                  
  // update kernel record                                                         
                                                                                  
  timers(&cpu_t2, &wall_t2);                                                      
  OP_kernels[0].name      = name;                                                 
  OP_kernels[0].count    += 1;                                                    
  OP_kernels[0].time     += wall_t2 - wall_t1;                                    
  OP_kernels[0].transfer += (float)set.size * arg0.size;                          
  OP_kernels[0].transfer += (float)set.size * arg1.size * 2.0f;                   
}                                                                                 
                                                                                  