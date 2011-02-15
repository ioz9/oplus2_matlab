%
% Source code transformation tool
%
% This tool parses the user's original source code
% to produce the CUDA code which will execute the
% user's kernel functions.
%
% The main deficiency of this current implementation
% is that it does not handle cases in which multiple 
% arguments involve the same underlying dataset.
%
% This prototype is written in MATLAB but a future
% version may use Python to avoid licensing costs.
% Alternatively, the MATLAB processor can be 
% "compiled" to produce a standalone version which
% can be freely distributed.
%
%
% usage: op2('filename')
%
% This takes as input 
%
% filename.cpp
%
% and produces as output
%
% filename_op.cpp
% filename_kernels.cu
%
% and one or more files of the form
%
% xxx_kernel.cu
%
% where xxx corresponds to the name of one of the
% kernel functions in filename.cpp
%

function op2(varargin)

global dims idxs typs indtyps inddims
global OP_typs_labels OP_typs_CPP

%
% declare constants
%

OP_ID  = 1;
OP_GBL = 2;
OP_PTR = 3;

OP_ptrs_labels = { 'OP_ID' 'OP_GBL' 'OP_PTR' };

OP_DOUBLE = 1;
OP_FLOAT  = 2;
OP_INT    = 3;
OP_BOOL   = 4;

OP_typs        = [  OP_DOUBLE   OP_FLOAT   OP_INT   OP_BOOL];   % IMPORTANT: arranged
OP_typs_labels = { 'OP_DOUBLE' 'OP_FLOAT' 'OP_INT' 'OP_BOOL' }; % in decreasing size
OP_typs_CPP    = { 'double'    'float '   'int   ' 'bool  '};

OP_READ  = 1;
OP_WRITE = 2;
OP_RW    = 3;
OP_INC   = 4;
OP_MAX   = 5;
OP_MIN   = 6;

OP_accs_labels = { 'OP_READ' 'OP_WRITE' 'OP_RW' 'OP_INC' 'OP_MAX' 'OP_MIN' };

date = datestr(now);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  loop over all input source files
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for narg = 1: nargin
  nkernels = 0;

  filename = varargin{narg};
  disp(sprintf('\nprocessing file %d of %d (%s)',narg,nargin,[filename '.cpp']));

  new_file = fileread([filename '.cpp']);
  src_file = regexprep(new_file,'\s','');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  parse file for next op_par_loop
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  while (~isempty(strfind(src_file,'op_par_loop_')))

    loc  = min(strfind(src_file,'op_par_loop_'));
    src_file = src_file(loc+12:end);

    [num,  src_file] = strtok(src_file,'(');
    nargs = str2num(num);
    [src_args, src_file] = strtok(src_file,')');
    src_args = src_args(2:end);

    loc = [0 strfind(src_args,',') length(src_args)+1];

    na = length(loc)-1;

    if (na ~= 3+6*nargs)
      error(sprintf('wrong number of arguments: expected %d, found %d',3+6*nargs, na));
    end

    for n = 1:na
      C{n} = src_args(loc(n)+1:loc(n+1)-1);
    end

    nkernels = nkernels + 1;
    fn_name  = C{1};
    disp(sprintf('\n  processing kernel %d (%s) with %d arguments',nkernels,fn_name,nargs));

%
% process parameters
%

    idxs = zeros(1,nargs);
    dims = zeros(1,nargs);
    ptrs = zeros(1,nargs);
    typs = zeros(1,nargs);
    accs = zeros(1,nargs);

    for m = 1:nargs
      idxs(m) = str2num(C{-1+6*m});
      dims(m) = str2num(C{ 1+6*m});

      if(isempty(strmatch(C{6*m},OP_ptrs_labels)))
        ptrs(m) = OP_PTR;
        if(idxs(m)<0)
          error(sprintf('invalid index for argument %d',m));
        end
      else
        ptrs(m) = strmatch(C{6*m},OP_ptrs_labels);
        if(idxs(m)~=-1)
          error(sprintf('invalid index for argument %d',m));
        end
      end

      if(isempty(strmatch(C{2+6*m},OP_typs_labels)))
        error(sprintf('unknown datatype for argument %d',m));
      else
        typs(m) = strmatch(C{2+6*m},OP_typs_labels);
      end

      if(isempty(strmatch(C{3+6*m},OP_accs_labels)))
        error(sprintf('unknown access type for argument %d',m));
      else
        accs(m) = strmatch(C{3+6*m},OP_accs_labels);
      end

      if(ptrs(m)==OP_GBL & (accs(m)==OP_WRITE | accs(m)==OP_RW))
        error(sprintf('invalid access type for argument %d',m));
      end

      if(ptrs(m)~=OP_GBL & (accs(m)==OP_MIN | accs(m)==OP_MAX))
        error(sprintf('invalid access type for argument %d',m));
      end

    end

    disp(['    local constants:    ' num2str(find(idxs<0 & ptrs==OP_GBL & accs==OP_READ)-1) ]);
    disp(['    global reductions:  ' num2str(find(idxs<0 & ptrs==OP_GBL & accs~=OP_READ)-1) ]);
    disp(['    direct arguments:   ' num2str(find(idxs<0 & ptrs(1:nargs)~=OP_GBL)-1) ]);
    disp(['    indirect arguments: ' num2str(find(idxs>=0)-1) ]);

%
%  identify indirect datasets
%

    ninds = 0;
    invinds  = zeros(1,nargs);
    inds     = zeros(1,nargs);
    indtyps  = ones(1,nargs);
    inddims  = zeros(1,nargs);
    indaccs  = zeros(1,nargs);

    for type = OP_typs
      j = find( idxs>=0 & typs==type );
      while (~isempty(j))
        match = strcmp(C(-2+6*j(1)),C(-2+6*j)) & (accs(j(1))==accs(j));
        ninds = ninds + 1; 
        indtyps(ninds) = typs(j(1));
        inddims(ninds) = dims(j(1));
        indaccs(ninds) = accs(j(1));
        inds(j(find(match))) = ninds;
        invinds(ninds) = j(1);
        j = j(find(~match));
      end
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  create new kernel file, starting with CUDA kernel function
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    local = 0;  % flag to say whether to use local variables

    file = strvcat('// user function         ',' ',...
                   '__device__               ',...
                  ['#include "' fn_name '.h"'],' ',' ',...
                   '// CUDA kernel function',' ',...
                  ['__global__ void op_cuda_' fn_name '(']);

    for m = 1:ninds
      line = '  INDTYP *ind_ARG, int *ind_ARG_ptr, int *ind_ARG_sizes, int *ind_ARG_offset,';
      file = strvcat(file,rep(line,m));
    end

    for m = 1:nargs
      if (ptrs(m)==OP_GBL & accs(m)==OP_READ)
        line = '  const TYP *ARG,';             % constants declared const for performance
      elseif (ptrs(m)==OP_GBL | ptrs(m)==OP_ID)
        line = '  TYP *ARG,';
      else
        line = '  int    *ARG_ptr,';
      end
      file = strvcat(file,rep(line,m));
    end

    if (ninds>0)
      file = strvcat(file,'  int     block_offset,',...
                          '  int    *blkmap,      ',...
                          '  int    *offset,      ',...
                          '  int    *nelems,      ',...
                          '  int    *ncolors,     ',...
                          '  int    *colors) {    ',' ');
    else
      file = strvcat(file,'  int     set_size ) {',' ');
    end

    for m = 1:ninds
      line = '  INDTYP *ind_ARG_s;';
      file = strvcat(file,rep(line,m));
    end

    for m = 1:nargs
      if (ptrs(m)==OP_GBL & accs(m)~=OP_READ)
        line = '  TYP  ARG_l[DIM];';
        file = strvcat(file,rep(line,m));
        if (accs(m)==OP_INC)
          line = '  for (int d=0; d<DIM; d++) ARG_l[d]=0;';
        else
          line = '  for (int d=0; d<DIM; d++) ARG_l[d]=ARG[d];';
        end
        file = strvcat(file,rep(line,m));
      else
        if (local | (ptrs(m)==OP_PTR & accs(m)==OP_INC) )
          line = '  TYP  ARG_l[DIM];';
          file = strvcat(file,rep(line,m));
        end
      end
    end

%
% lengthy code for general case with indirection
%
    if (ninds>0)
      file = strvcat(file,' ',...
                          '  extern __shared__ int shared[];',' ',...
                          '  // get block info',' ',...
                          '  int blockId = blkmap[blockIdx.x + block_offset];',' ');

      file = strvcat(file,'  // get sizes and shift pointers and direct-mapped data',' ');
      for m = 1:ninds
        line = '  int ind_ARG_size = ind_ARG_sizes[blockId];';
        file = strvcat(file,rep(line,m));
      end
      file = strvcat(file,' ');
      for m = 1:ninds
        line = '  ind_ARG_ptr += ind_ARG_offset[blockId];';
        file = strvcat(file,rep(line,m));
      end
      file = strvcat(file,' ');
      for m = 1:nargs
        if (ptrs(m)==OP_ID)
          line = '  ARG         += offset[blockId]*DIM;';
          file = strvcat(file,rep(line,m));
        elseif(ptrs(m)==OP_PTR)
          line = '  ARG_ptr     += offset[blockId];';
          file = strvcat(file,rep(line,m));
        end
      end

      file = strvcat(file,'  colors       += offset[blockId];',' ');

      file = strvcat(file,'  // set shared memory pointers',' ');
      for m = 1:ninds
        if (m==1)
          line = '  ind_ARG_s = (INDTYP *) shared;';
          file = strvcat(file,rep(line,m));
        else
          line1 = '  ind_ARG_s = (INDTYP *)';
          line2 = ' &ind_ARG_s[ind_ARG_size*INDDIM];';
          file = strvcat(file,[rep(line1,m) rep(line2,m-1)]);
        end
      end

      file = strvcat(file,' ','  // copy indirect datasets into shared memory or zero increment',' ');
      for m = 1:ninds
        line = '  for (int n=threadIdx.x; n<INDARG_size; n+=blockDim.x)';
        file = strvcat(file,rep(line,m));
        line = '    for (int d=0; d<INDDIM; d++)';
        file = strvcat(file,rep(line,m));
        if(indaccs(m)==OP_READ | indaccs(m)==OP_RW)
          line = '      INDARG_s[d+n*INDDIM] = INDARG[d+INDARG_ptr[n]*INDDIM];';
        elseif(indaccs(m)==OP_INC)
          line = '      INDARG_s[d+n*INDDIM] = 0;';
        end
        file = strvcat(file,rep(line,m),' ');
      end
      file = strvcat(file,'  __syncthreads();',' ');

      file = strvcat(file,'  // process set elements                     ',' ', ...
                          '  int nelems2 = blockDim.x*(1+(nelems[blockId]-1)/blockDim.x);',' ',...
                          '  for (int n=threadIdx.x; n<nelems2; n+=blockDim.x) {         ',    ...
                          '    int col2 = ncolors[blockId];                              ',' ',...
                          '    if (n<nelems[blockId]) {                                  ',' ',...
                          '      // initialise local variables                           ',' ');

      for m = 1:nargs
        if (ptrs(m)~=OP_GBL & (local | (ptrs(m)==OP_PTR & accs(m)==OP_INC)))
          if (accs(m)==OP_READ | accs(m)==OP_RW)
            line = '      for (int d=0; d<DIM; d++)';
            file = strvcat(file,rep(line,m));
            if (ptrs(m)==OP_ID)
              line = '        ARG_l[d] = ARG[d+n*DIM];';
            else
              line = sprintf('        ARG_l[d] = ind_arg%d_s[d+ARG_ptr[n]*DIM];',inds(m)-1);
            end
            file = strvcat(file,rep(line,m));

          elseif (accs(m)==OP_INC)
            line = '      for (int d=0; d<DIM; d++)';
            file = strvcat(file,rep(line,m));
            line = '        ARG_l[d] = 0;';
            file = strvcat(file,rep(line,m));
          end
        end
      end
%
% simple alternative when no indirection
%
    else
      file = strvcat(file,' ','  // process set elements',' ', ...
                              '  for (int n=threadIdx.x+blockIdx.x*blockDim.x;', ...
                              '       n<set_size; n+=blockDim.x*gridDim.x) {');

      if(local)
        file = strvcat(file,' ','    // initialise local variables ',' ');

        for m = 1:nargs
          if (accs(m)==OP_READ | accs(m)==OP_RW)
            line = '    for (int d=0; d<DIM; d++)';
            file = strvcat(file,rep(line,m));
            line = '      ARG_l[d] = ARG[d+n*DIM];';
            file = strvcat(file,rep(line,m));

          elseif (accs(m)==OP_INC)
            line = '    for (int d=0; d<DIM; d++)';
            file = strvcat(file,rep(line,m));
            line = '      ARG_l[d] = 0;';
            file = strvcat(file,rep(line,m));
          end
        end
      end
    end

%
% kernel call
%

    file = strvcat(file,' ','      // user-supplied kernel call',' ');

    for m = 1:nargs
      line = ['      ' fn_name '( '];
      if (m~=1)
        line = blanks(length(line));
      end
      if (local | (ptrs(m)~=OP_ID & accs(m)==OP_INC) )
        line = [ line 'ARG_l,' ];
      elseif (ptrs(m)==OP_GBL)
        line = [ line 'ARG,' ];
      elseif (ptrs(m)==OP_ID)
        line = [ line 'ARG+n*DIM,' ];
      elseif (ptrs(m)==OP_PTR)
        line = [ line sprintf('ind_arg%d_s+ARG_ptr[n]*DIM,',inds(m)-1) ];
      else
        error('internal error 1')
      end
      if (m==nargs)
        line = [ line(1:end-1) ' );' ];
      end
      file = strvcat(file,rep(line,m));
    end

%
% updating for indirect kernels ...
%
    if(ninds>0) 
      file = strvcat(file,' ','      col2 = colors[n];     ',...
                              '    }                        ',' ',...
                              '    // store local variables ',' ');

      for m = 1:nargs
        if (ptrs(m)~=OP_GBL & (local | (ptrs(m)==OP_PTR & accs(m)==OP_INC)))
          if (accs(m)==OP_WRITE | accs(m)==OP_RW)
            line = '    for (int d=0; d<DIM; d++)';
            file = strvcat(file,rep(line,m));
            if (ptrs(m)==OP_ID)
              line = '      ARG[d+n*DIM] = ARG_l[d];';
            else
              line = sprintf('      ind_arg%d_s[d+ARG_ptr[n]*DIM] = ARG_l[d];',inds(m)-1);
            end
            file = strvcat(file,rep(line,m));

          elseif (accs(m)==OP_INC)
            if (ptrs(m)==OP_ID)
              line = '    for (int d=0; d<DIM; d++)';
              file = strvcat(file,rep(line,m));
              line = '      ARG[d+n*DIM] += ARG_l[d];';
              file = strvcat(file,rep(line,m));
            else
              file = strvcat(file, ...
               '    for (int col=0; col<ncolors[blockId]; col++) {', ...
               '      if (col2==col) ');
              line = '        for (int d=0; d<DIM; d++)';
              file = strvcat(file,rep(line,m));
              line = sprintf('          ind_arg%d_s[d+ARG_ptr[n]*DIM] += ARG_l[d];',inds(m)-1);
              file = strvcat(file,rep(line,m), ...
               '      __syncthreads();','    }',' ');
            end
          end
        end
      end

      file = strvcat(file,'  }',' ','  // apply pointered write/increment',' ');
      for m = 1:ninds
        if(indaccs(m)==OP_WRITE | indaccs(m)==OP_RW)
          line = '  for (int n=threadIdx.x; n<INDARG_size; n+=blockDim.x)';
          file = strvcat(file,rep(line,m));
          line = '    for (int d=0; d<INDDIM; d++)';
          file = strvcat(file,rep(line,m));
          line = '      INDARG[d+INDARG_ptr[n]*INDDIM] = INDARG_s[d+n*DIM];';
          file = strvcat(file,rep(line,m),' ');
        elseif(indaccs(m)==OP_INC)
          line = '  for (int n=threadIdx.x; n<INDARG_size; n+=blockDim.x)';
          file = strvcat(file,rep(line,m));
          line = '    for (int d=0; d<INDDIM; d++)';
          file = strvcat(file,rep(line,m));
          line = '      INDARG[d+INDARG_ptr[n]*INDDIM] += INDARG_s[d+n*DIM];';
          file = strvcat(file,rep(line,m),' ');
        end
      end
%
% ... and direct kernels
%
    else
      if (local)
        file = strvcat(file,'    // store local variables ',' ');

        for m = 1:nargs
          if (accs(m)==OP_WRITE | accs(m)==OP_RW)
            line = '    for (int d=0; d<DIM; d++)';
            file = strvcat(file,rep(line,m));
            line = '      ARG[d+n*DIM]  = ARG_l[d];';
            file = strvcat(file,rep(line,m));

          elseif (accs(m)==OP_INC)
            line = '    for (int d=0; d<DIM; d++)';
            file = strvcat(file,rep(line,m));
            line = '      ARG[d+n*DIM] += ARG_l[d];';
            file = strvcat(file,rep(line,m));
          end
        end
      end
      file = strvcat(file,'  }');
    end

%
% global reduction
%
    if (length(find(ptrs==OP_GBL & accs~=OP_READ))>0)
      file = strvcat(file,' ','  // global reductions',' ');
      for m = 1:nargs
        if (ptrs(m)==OP_GBL & accs(m)~=OP_READ)
          if(accs(m)==OP_INC)
            line = '  op_atomic_inc(ARG,ARG_l,DIM);';
          elseif (accs(m)==OP_MIN)
            line = '  op_atomic_min(ARG,ARG_l,DIM);';
          elseif (accs(m)==OP_MAX)
            line = '  op_atomic_max(ARG,ARG_l,DIM);';
          else
            error('internal error: invalid reduction option')
          end
          file = strvcat(file,rep(line,m));
        end
      end
    end

    file = strvcat(file,'}');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% then C++ stub function
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    file = strvcat(file,' ',' ','// host stub function            ',' ','extern "C"');
    file = strvcat(file,['void op_par_loop_' fn_name '(char const * name, op_set set,']);
    for m = 1:nargs
      if(ptrs(m)==OP_GBL)
        line = ['  TYP *arg%dh,int idx%d, op_ptr ptr%d, int dim%d,' ...
                ' op_datatype typ%d, op_access acc%d'];
      else
        line = ['  op_dat  arg%d, int idx%d, op_ptr ptr%d, int dim%d,' ...
                ' op_datatype typ%d, op_access acc%d'];
      end
      line = rep(sprintf(line, m-1,m-1,m-1,m-1,m-1,m-1),m);
    
      if (m<nargs)
        file = strvcat(file,[line ',']);
      else
        file = strvcat(file,[line '){'],' ');
      end
    end

    for m = 1:nargs
      if (ptrs(m)==OP_GBL)
        line = '  op_dat ARG = {OP_NULL_SET,0,0,0,(char *)ARGh,NULL,TYP2,"gbl"};';
        file = strvcat(file,rep(line,m));
      end
    end

%
%   indirect bits
%
    if (ninds>0)
      file = strvcat(file,' ',...
             sprintf('  int         nargs = %d, ninds = %d;',nargs,ninds),' ');

      for l=1:6
        if (l==1)
          word = 'arg';
          line = sprintf('  op_dat      args[%d] = {',nargs);
        elseif (l==2)
          word = 'idx';
          line = sprintf('  int         idxs[%d] = {',nargs);
        elseif (l==3)
          word = 'ptr';
          line = sprintf('  op_ptr      ptrs[%d] = {',nargs);
        elseif (l==4)
          word = 'dim';
          line = sprintf('  int         dims[%d] = {',nargs);
        elseif (l==5)
          word = 'typ';
          line = sprintf('  op_datatype typs[%d] = {',nargs);
        elseif (l==6)
          word = 'acc';
          line = sprintf('  op_access   accs[%d] = {',nargs);
        end

        for m = 1:nargs
          if (m<nargs)
            line = strcat(line,word,num2str(m-1),', ');
          else
            line = strcat(line,word,num2str(m-1),'};');
          end
        end
        file = strvcat(file,line);
      end

      line = sprintf('  int         inds[%d] = {',nargs);
      for m = 1:nargs
        if (m<nargs)
          line = strcat(line,num2str(inds(m)-1),', ');
        else
          line = strcat(line,num2str(inds(m)-1),'};');
        end
      end
      file = strvcat(file,line);

      file = strvcat(file,' ',...
       '  if (OP_DIAGS>1) {              ',...
      ['    printf(" kernel routine with indirection: ' fn_name ' \n");'],...
       '  }                              ');

%
% direct bit
%
    else
      file = strvcat(file,' ',...
       '  if (OP_DIAGS>1) {              ',...
      ['    printf(" kernel routine w/o indirection:  ' fn_name ' \n");'],...
       '  }                              ');
    end

%
% transfer constants
%
    if (length(find(ptrs(1:nargs)==OP_GBL & accs(1:nargs)==OP_READ))>0)
      file = strvcat(file,'  ',...
       '  // transfer constants to GPU',' ',...
       '  int consts_bytes = 0;');

      ng = 0;
      for type = OP_typs
        for m=1:nargs
          if(ptrs(m)==OP_GBL & accs(m)==OP_READ & typs(m)==type);
            ng = ng + 1;
            line = '  consts_bytes += DIM*sizeof(TYP);';
            file = strvcat(file,rep(line,m));
          end
        end
      end

      file = strvcat(file,'  ',...
       '  reallocConstArrays(consts_bytes);',' ',...
       '  consts_bytes = 0;');

      ng = 0;
      for type = OP_typs
        for m=1:nargs
          if(ptrs(m)==OP_GBL & accs(m)==OP_READ & typs(m)==type);
            ng = ng + 1;
            line = '  ARG.dat   = OP_consts_h + consts_bytes;';
            file = strvcat(file,rep(line,m));
            line = '  ARG.dat_d = OP_consts_d + consts_bytes;';
            file = strvcat(file,rep(line,m));
            line = '  for (int i=0; i<DIM; i++) ((TYP *)ARG.dat)[i] = ((TYP *)ARGh)[i];';
            file = strvcat(file,rep(line,m));
            line = '  consts_bytes += DIM*sizeof(TYP);';
            file = strvcat(file,rep(line,m));
          end
        end
      end

      file = strvcat(file,'  ','  mvConstArraysToDevice(consts_bytes);');
    end

%
% transfer global reduction initial data
%
    if (length(find(ptrs(1:nargs)==OP_GBL & accs(1:nargs)~=OP_READ))>0)
      file = strvcat(file,'  ',...
       '  // transfer global reduction data to GPU',' ',...
       '  int reduct_bytes = 0;');

      ng = 0;
      for type = OP_typs
        for m=1:nargs
          if(ptrs(m)==OP_GBL & accs(m)~=OP_READ & typs(m)==type);
            ng = ng + 1;
            line = '  reduct_bytes += DIM*sizeof(TYP);';
            file = strvcat(file,rep(line,m));
          end
        end
      end

      file = strvcat(file,'  ',...
       '  reallocReductArrays(reduct_bytes);',' ',...
       '  reduct_bytes = 0;');

      ng = 0;
      for type = OP_typs
        for m=1:nargs
          if(ptrs(m)==OP_GBL & accs(m)~=OP_READ & typs(m)==type);
            ng = ng + 1;
            line = '  ARG.dat   = OP_reduct_h + reduct_bytes;';
            file = strvcat(file,rep(line,m));
            line = '  ARG.dat_d = OP_reduct_d + reduct_bytes;';
            file = strvcat(file,rep(line,m));
            line = '  for (int i=0; i<DIM; i++) ((TYP *)ARG.dat)[i] = ARGh[i];';
            file = strvcat(file,rep(line,m));
            line = '  reduct_bytes += DIM*sizeof(TYP);';
            file = strvcat(file,rep(line,m));
          end
        end
      end

      file = strvcat(file,'  ','  mvReductArraysToDevice(reduct_bytes);');
    end

%
% kernel call for indirect version
%
    if (ninds>0) 
      file = strvcat(file,' ',...
       '  // get plan                    ',' ',...
       '  op_plan *Plan = plan(name,set,nargs,args,idxs,ptrs,dims,typs,accs,ninds,inds);',' ',...
       '  // execute plan                ',' ',...
       '  int block_offset = 0;          ',' ',...
       '  for (int col=0; col<(*Plan).ncolors; col++) { ',' ',...
       '    int nblocks = (*Plan).ncolblk[col];         ',...
       '    int nshared = (*Plan).nshared;              ',' ',...
      ['    op_cuda_' fn_name '<<<nblocks,64,nshared>>>(']);

      for m = 1:ninds
        line = [ '       (TYP *)ARG.dat_d, ' ...
         sprintf('(*Plan).ind_ptrs[%d], (*Plan).ind_sizes[%d], (*Plan).ind_offs[%d],',m-1,m-1,m-1) ];
        file = strvcat(file,rep(line,invinds(m)));
      end

      for m = 1:nargs
        if (inds(m)==0)
          line = '       (TYP *)ARG.dat_d,';
        else
          line = sprintf('       (*Plan).ptrs[%d],',m-1);
        end
        file = strvcat(file,rep(line,m));
      end

      file = strvcat(file, ... 
        '       block_offset,                                       ', ...
        '       (*Plan).blkmap,                                     ', ...
        '       (*Plan).offset,                                     ', ...
        '       (*Plan).nelems,                                     ', ...
        '       (*Plan).nthrcol,                                    ', ...
        '       (*Plan).thrcol);                                    ',' ', ...
        '    cutilSafeCall(cudaThreadSynchronize());                 ', ...
       ['    cutilCheckMsg("op_cuda_' fn_name ' execution failed\n");'],' ', ...
        '    block_offset += nblocks;                                ', ...
        '  }                                                         ');

%
% kernel call for direct version
%
    else
      file = strvcat(file,' ','  // execute plan                ',' ');

      for m = 1:nargs
        line = ['  op_cuda_' fn_name '<<<100,64>>>( '];
        if (m>1)
          line = blanks(length(line));
        end
        file = strvcat(file,rep([line '(TYP *) ARG.dat_d,'],m));
      end

      file = strvcat(file,[ blanks(length(line)) 'set.size );'],' ',... 
       ['  cutilCheckMsg("op_cuda_', fn_name ' execution failed\n");']);
    end

%
% transfer global reduction initial data
%
    if (length(find(ptrs(1:nargs)==OP_GBL & accs(1:nargs)~=OP_READ))>0)
      file = strvcat(file,' ','  // transfer global reduction data back to CPU',...
                          ' ','  mvReductArraysToHost(reduct_bytes);',' ');
      for type = OP_typs
        for m=1:nargs
          if(ptrs(m)==OP_GBL & accs(m)~=OP_READ & typs(m)==type);
            line = '  for (int i=0; i<DIM; i++) ARGh[i] = ((TYP *)ARG.dat)[i];';
            file = strvcat(file,rep(line,m));
          end
        end
      end
    end

    file = strvcat(file,'} ',' ');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  output individual kernel file
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    fid = fopen(strcat(fn_name,'_kernel.cu'),'wt');
    fprintf(fid,'// \n// auto-generated by op2.m on %s \n//\n\n',date);
    for n=1:size(file,1)
      fprintf(fid,'%s\n',file(n,:));
    end
    fclose(fid);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  append kernel bits for new source file and master kernel file
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    old = [ 'op_par_loop_' num2str(nargs) '(' fn_name ','];
    new = [ 'op_par_loop_' fn_name '('];
    new_file = regexprep(new_file,old,new);

    if (nkernels==1)
      new_file2 = ' ';
      if (narg==1)
        ker_file2 = ' ';
      end
    end

    new_file2 = strvcat(new_file2,...
     'extern "C"                                             ' ,...
    ['void op_par_loop_' fn_name '(char const *, op_set,   ']);

    for n = 1:nargs
      if (ptrs(n)==OP_GBL)
        line = [ '  ' OP_typs_CPP{typs(n)} '*, int, op_ptr, int, op_datatype, op_access' ];
      else
        line = '  op_dat, int, op_ptr, int, op_datatype, op_access';
      end
      if (n==nargs)
        new_file2 = strvcat(new_file2,[line ');'],' ');
      else
        new_file2 = strvcat(new_file2,[line ',']);
      end
    end

    ker_file2 = strvcat(ker_file2, ['#include "' fn_name '_kernel.cu"']);
  end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  output new source file
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  new_file2 = strvcat( ...
  '#include "op_datatypes.h"                                                      ',...
  '                                                                               ',... 
  'extern void op_init(int, char **);                                             ',...
  '                                                                               ',...
  'extern void op_decl_set(int, op_set &, char const *);                          ',...
  '                                                                               ',... 
  'extern void op_decl_ptr(op_set, op_set, int, int *, op_ptr &, char const *);   ',...
  '                                                                               ',... 
  'extern void op_decl_dat(op_set,int,op_datatype,double *,op_dat &,char const *);',...
  'extern void op_decl_dat(op_set,int,op_datatype,float  *,op_dat &,char const *);',...
  'extern void op_decl_dat(op_set,int,op_datatype,int    *,op_dat &,char const *);',...
  '                                                                               ',... 
  'extern void op_decl_const(int, op_datatype, double *, char const *);           ',...
  'extern void op_decl_const(int, op_datatype, float  *, char const *);           ',...
  'extern void op_decl_const(int, op_datatype, int    *, char const *);           ',...
  '                                                                               ',...  
  'extern void op_fetch_data(op_dat);                                             ',... 
  '                                                                               ',... 
  'extern void op_diagnostic_output();                                            ',... 
  '                                                                               ',... 
  '//                                                                             ',... 
  '// op_par_loop declarations                                                    ',... 
  '//                                                                             ',... 
  new_file2);


  loc = strfind(new_file,'#include "op_seq.h"');

  fid = fopen(strcat(filename,'_op.cpp'),'wt');
  fprintf(fid,'// \n// auto-generated by op2.m on %s \n//\n\n',date);
  fprintf(fid,'%s',new_file(1:loc-1));

  for n=1:size(new_file2,1)
    fprintf(fid,'%s\n',new_file2(n,:));
  end

  fprintf(fid,'%s',new_file(loc+20:end));

  fclose(fid);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  process global constants for master kernel file
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  if(narg==1)
     ker_file1 = strvcat('// header                ',' ',...
                         '#include "op_lib.cu"     ',' ',...
                         '// global constants      ',' ');
  end

  src_file = fileread([filename '.cpp']);
  src_file = regexprep(src_file,'\s','');

  while (~isempty(strfind(src_file,'op_decl_const(')))
    loc  = min(strfind(src_file,'op_decl_const('));
    src_file = src_file(loc+14:end);
    [src_args, src_file] = strtok(src_file,')');

    loc = [0 strfind(src_args,',') length(src_args)+1];
    na  = length(loc)-1;

    if( na ~= 4)
      error(sprintf('wrong number of arguments in op_decl_const'));
    end

    for n = 1:na
      C{n} = src_args(loc(n)+1:loc(n+1)-1);
    end

    if(isempty(strmatch(C{2},OP_typs_labels)))
      error('unknown datatype in op_decl_const');
    else
      type = OP_typs_CPP{strmatch(C{2},OP_typs_labels)};
    end

    dim = str2num(C{1});
    if (dim==1)
      ker_file1 = strvcat(ker_file1,...
         [ '__constant__ ' type ' ' C{4}(2:end-1) ';' ]);
    else
      ker_file1 = strvcat(ker_file1,...
         [ '__constant__ ' type ' ' C{4}(2:end-1) '[' C{1} '];' ]);
    end

    disp(sprintf('\n  global constant (%s) of size %s',C{4}(2:end-1),C{1}));
  end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  output one master kernel file
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

file = strvcat(ker_file1,' ','// user kernel files',ker_file2);

fid = fopen([ varargin{1} '_kernels.cu'],'wt');
fprintf(fid,'// \n// auto-generated by op2.m on %s \n//\n\n',date);

for n=1:size(file,1)
  fprintf(fid,'%s\n',file(n,:));
end
fclose(fid);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% a little function to replace keywords
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function line = rep(line,m)

global dims idxs typs indtyps inddims
global OP_typs_labels OP_typs_CPP

line = regexprep(line,'INDDIM',num2str(inddims(m)));
line = regexprep(line,'INDARG',sprintf('ind_arg%d',m-1));
line = regexprep(line,'INDTYP',OP_typs_CPP{indtyps(m)});

line = regexprep(line,'DIM',num2str(dims(m)));
line = regexprep(line,'ARG',sprintf('arg%d',m-1));
line = regexprep(line,'TYP2',OP_typs_labels{typs(m)});
line = regexprep(line,'TYP',OP_typs_CPP{typs(m)});
line = regexprep(line,'IDX',num2str(idxs(m)));
