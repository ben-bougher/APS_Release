function segy_make_job(filepath,filename_string,il_byte,xl_byte,...
                       offset_byte,parallel,anggath,output_dir, block_size)
    %% ------------------ FUNCTION DEFINITION ---------------------------------
    % segy_make_job: function to scan SEGY file to gain geometry and
    % sample information used by other functions.
    %   Arguments:
    %       filepath =          path of directory containing input angle stacks only as cell array, {'/path/'}
    %       filename_string =   name of search-string in SEGY file name to scan
    %       il_byte  =          inline number byte location (189 for SEGY Rev1 format)
    %       xl_byte  =          crossline number byte location (193 for SEGY Rev1 format)
    %       output_dir =        directory in which all DIGI outputs should be saved.
    %       offset_byte =       Offset byte location (37 for SEGY Rev1 format)
    %   
    %   Outputs:
    %       .mat file = metadata including sample rate, n_samples etc.
    %       .mat_lite file = binary file containing IL/XL byte locations.
    %
    %   Writes to Disk:
    %       job meta files: give description and paths

    %%

    
    
    %%-------------------PROCESSING FUNCTION ARGUMENTS--------------------------
    % Column numbers define output format of .mat_lite file. 
    % Should make this a global format definition.  
    job_meta = {};


    % TODO Why does this need to be a cell?
    if ~iscell(filepath)
        filepath_cell{1} = filepath;
        clear filepath
        filepath = filepath_cell;
        clear filepath_cell;
    end

    
    %% Read the segy files
    [files_in,nfiles] = directory_scan(filepath,filename_string); 
    files_in.names = sort_nat(files_in.names);      


    
    %% Make the mat_lite summary files
    % Scan through each SEGY file and summarize the relevant trace header
    % information in a .mat_orig_lite file
    for i_file = 1:1:nfiles
        
        filename = files_in.names{i_file};                         
        filepath = files_in.path{i_file};     
        
        [path, name, ext] = fileparts(filename);
     
        if( strcmp(ext,'.segy') | strcmp(ext, '.sgy'))
            
          
            % Scan segy and make mat file <file name.mat_orig_lite> with structure 
            % of format [ PKey SKey Byte_Loc SKey_max SKey_inc TKey TKey_max TKey_inc ]
       
            if exist(strcat(output_dir,name, '.mat_lite'), 'file') ~= 2
                segy_make_structure(strcat(filepath, filename),il_byte, xl_byte, ...
                                    offset_byte,block_size); 
            end
        end

    end
    
    
    %% Initialize the job meta file
    job_meta = job_meta_init(files_in, output_dir, il_byte, xl_byte,...
        offset_byte);
    
    % Add the information from the seismic headers
    job_meta = job_meta_add_seismic_hdrs(job_meta);
    
    
    %% Output the job meta
    str_date = date;
    str_date = regexprep(str_date, '-', '');
    job_meta_dir = strcat(job_meta.output_dir,'job_meta/');
    mkdir(job_meta_dir);
    job_meta_path = strcat(job_meta_dir,'job_meta_',str_date, ...
                           '.mat');
     % Saves Seismic structure to mat file
    save(job_meta_path,'-struct','job_meta','-v7.3');

    
    %% Make data blocks and the lookups for each block
    dispstrj = 'starting to make blocks';
    disp(dispstrj);

    [job_meta.block_keys,job_meta.n_blocks] = segy_make_blocks(job_meta_path);

    % Saves Seismic structure to mat file
    save(job_meta_path,'-struct','job_meta','-v7.3'); 

    % ##################################################################
    % Find live blocks

    job_meta.liveblocks = select_live_blocks(job_meta_path);
     % Saves Seismic structure to mat file
    save(job_meta_path,'-struct','job_meta','-v7.3');

    fprintf('Saved seismic structure to file ...\n')

end
        
        


function job_meta = job_meta_init(files_in, output_dir, il_byte, ...
    xl_byte, offset_byte)
%% Function Definition
% Initializes a job metadata structure from a list of segy files
% 
%  Input:
%     files_in: A list of segy files to in the job
%
%  Output:
%      job_meta structure
%%
    
    for i_file = 1:size(files_in.names,2)
    
        % Add file name to the job meta
        job_meta.files{i_file} = regexprep(files_in.names{i_file}, 'segy|sgy', ...
                                           'mat_lite');
    end
    
    %--------RESTRUCTURE JOB META FILE (REMOVE NON-ENTRIES,
    % DUPLICATIONS, ETC)  AND ENTER MORE INFO IN JOB_META FILE--------
    % job_meta.files = cell2mat(job_meta.files);

    count = 1;                                          
    for i_file = 1:1:size(job_meta.files,2)  
        
        if ~isempty(job_meta.files{i_file})
            files_tmp{count} = job_meta.files{i_file}; 
            count = count + 1;                        
        end     
        
    end

    job_meta.files = unique(files_tmp);                
    job_meta.paths = unique(files_in.path');           
    job_meta.output_dir = output_dir;                   
    job_meta.il_byte = il_byte;                         
    job_meta.xl_byte = xl_byte;                        
    job_meta.offset_byte = offset_byte;                
    
end

function job_meta = job_meta_add_seismic_hdrs(job_meta)
%% Function Definition
% Adds the seismic header information to the job meta structure
%
% Inputs: 
%   job_meta:  Job metadata structure
%
% Outputs: None
%%

    pkey_loc = 1;               % column numbers needs to be implemented Primary Key
    skey_loc = 2;               % Secondary Key
    byte_loc = 3;               % Byte location
    skey_max_loc = 4;           % Secondary Key Maximum
    skey_inc_loc = 5;           % Secondary Key Increment  
    tkey_loc = 6;               % Tertiary Key
    tkey_max_loc = 7;           % Tertiary Key Maximum
    tkey_inc_loc = 8;           % Tertiary Key Increment 
    
    files = job_meta.files;
    nfiles = size(files,2);

    i_vol = 1;
    ii = 1;
    job_meta.vol_traces{i_vol,1} = 0;
    
    %---loop round all the mat_lite files to do with this job-------
    for il = 1:nfiles          
                       
        % Get the basic header information
        seismic = segy_read_binary(strcat(job_meta.paths{1},...
                                              files{il}));              


        job_meta.vol_traces{i_vol,1} = job_meta.vol_traces{i_vol,1}+...
            seismic.n_traces;
           
        % primary key range
        pkey_min(ii) = min(seismic.trace_ilxl_bytes(seismic.trace_ilxl_bytes(:,pkey_loc) > 0,pkey_loc));
        pkey_max(ii) = max(seismic.trace_ilxl_bytes(:, pkey_loc));
           
        % primary increment (take the mode)
        if pkey_min(ii) == pkey_max(ii)
            pkey_inc(ii) = 1;
        else
            pkey_inc(ii) = mode(diff(unique(seismic.trace_ilxl_bytes(:,pkey_loc))));
        end
            
        % secondary key range
        skey_min(ii) = min(seismic.trace_ilxl_bytes(seismic.trace_ilxl_bytes(:,skey_loc) > 0,skey_loc));
        skey_max(ii) = max(seismic.trace_ilxl_bytes(:,skey_max_loc));
            
        % take the mode for the increment
        if skey_min(ii) == skey_max(ii)
            skey_inc(ii) = 1;
        else
                
            % TODO the mode could be an ugly way of doing this
            skey_inc(ii) = ...
                mode(seismic.trace_ilxl_bytes(...
                    (seismic.trace_ilxl_bytes(:,skey_max_loc) - seismic.trace_ilxl_bytes(:,skey_loc))...
                    .* seismic.trace_ilxl_bytes(:,skey_inc_loc) > 0,skey_inc_loc));
        end
           
        
        % Range and increment of tertiary key
        tkey_min(ii) = min(seismic.trace_ilxl_bytes(:,tkey_loc));
        tkey_max(ii) = max(seismic.trace_ilxl_bytes(:,tkey_max_loc));
        tkey_inc(ii) = mode(seismic.trace_ilxl_bytes(:,tkey_inc_loc));
                
        job_meta.n_samples{i_vol} = seismic.n_samples;  % Number f samples in the current Volume
        job_meta.trc_head{i_vol} = 240;                 % Length of trace header??
        job_meta.bytes_per_sample{i_vol} = 4;           % Number of bytes per sample. Usually 4
        job_meta.vol_nblocks(i_vol,1) = ii-1;
        job_meta.pkey_min(i_vol,1) = min(pkey_min);     % Minimum of Primary Key (inline generally)
        job_meta.pkey_max(i_vol,1) = max(pkey_max);     % Maximum of Primary Key (inline generally)
        job_meta.pkey_inc(i_vol,1) = mode(pkey_inc);    % Mode of Primary Key (inline generally)
        job_meta.skey_min(i_vol,1) = min(skey_min);     % Minimum of Secondary Key (xline generally)
        job_meta.skey_max(i_vol,1) = max(skey_max);     % Maximum of Secondary Key (xline generally)
        job_meta.skey_inc(i_vol,1) = mode(skey_inc);    % Mode of Secondary Key (xline generally)
        
        
        job_meta.tkey_min(i_vol,1) = min(tkey_min); % Minimum of tertiary Key (angle)
        job_meta.tkey_max(i_vol,1) = max(tkey_max); % Maximum of tertiary Key (angle)
        job_meta.tkey_inc(i_vol,1) = mode(tkey_inc);% Mode of tertiary Key (angle)
        job_meta.is_gather = 1;
            
            
        job_meta.s_rate = seismic.s_rate;
            
        
    end
end
