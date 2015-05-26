function compress_ilxl_bytes = gather_compress_ilxl_bytes_offset(trace_ilxl_bytes,blocktr)

%% ------------------ FUNCTION DEFINITION ---------------------------------
% Compress scanned SEGY trace headers by finding repeating
% patterns. Only for pre-stack datasets.
%
%   Arguments:
%       trace_ilxl_bytes [pkey, skey, byte_location, tkey] = scan of trace headers created by segy_make_structure
%       blocktr = number of input traces  
%   
%   Outputs:
%       compress_ilxl_bytes [pkey, skey, byte_location, skey_max,
%       skey_inc, tkey, tkey_max, tkey_inc]  = compressed version of trace_ilxl_bytes
%
%   Writes to Disk:
%       nothing
%%
    
    % This should really be part of a structure definition somewhere
    pkey_loc = 1; % column numbers needs to be implemented
    skey_loc = 2;
    byte_loc = 3;
    tkey_loc = 4;

    % Compress the tertiary keys
    if blocktr > 1
        compress_offset_bytes = compress_tkeys(trace_ilxl_bytes, blocktr);
    
        compress_ilxl_bytes = compress_skeys(compress_offset_bytes)
             
    else % for blocktr = 1 (1 trace per block)
       
        for j =1:size(trace_ilxl_bytes)
            compress_ilxl_bytes = [ trace_ilxl_bytes(j,pkey_loc) ...
                                trace_ilxl_bytes(j,skey_loc) ...
                                trace_ilxl_bytes(j,byte_loc) ...
                                trace_ilxl_bytes(j,skey_loc) 1 ...
                                trace_ilxl_bytes(j,4) ...
                                trace_ilxl_bytes(j,4) 1];
        end
    end
end


        
function compressed_lookup = compress_tkeys(trace_ilxl_bytes, ...
                                              blocktr)
    %% Function Description
    % Compresses byte lookup information by defining the tertiary
    % key information relative to the other keys.
    %
    % Assumes: Tkeys have uniform increments
    %
    % Arguments:
    % trace_ilxl_bytes [pkey skey tbyte tkey] = Lookup information
    %   for every trace.  
    % blocktr (int) = The number of traces in each data block
    %
    % Outputs:
    % compressed_lookup [pkey skey tbyte(byte location of trace) ~
    % skey_increment ~]
    %%
    
    
    pkey_loc = 1; % column numbers needs to be implemented
    skey_loc = 2;
    byte_loc = 3;
    tkey_loc = 4;

    trace_ilxl_bytes(1:end-1,5) = diff(trace_ilxl_bytes(:,4));

    % I really don't like these initializations
    start_idx = 1;
    count = 0;
    tcount = 1;
    row_i = 1;
    pkey_prev = -995837;
    skey_prev = -9999437;

    for row_i = start_idx:blocktr
        
        pkey = trace_ilxl_bytes(row_i,pkey_loc);
        skey = trace_ilxl_bytes(row_i,skey_loc);
        tkey = trace_ilxl_bytes(row_i,tkey_loc);
        tbyte = trace_ilxl_bytes(row_i,byte_loc);
        tkey_inc = trace_ilxl_bytes(row_i,5);
        
        if pkey == pkey_prev % same inline
            
            if skey == skey_prev
                
                % Increment the tertiary count
                tcount = tcount + 1;
                
                % the number of tkeys will be the skey increment
                % set the tertiary key to 1
                compress_offset_bytes(count,5:6) = [tcount 1];
                skey_prev = skey;
                
            else % new secondary point
                
                % reset the teriary key count, make new point
                tcount = 1;
                count = count + 1;
                
                % make a new lookup structure for the new point
                compress_offset_bytes(count,:) = [ pkey skey tbyte 1 1 1];
                skey_prev = skey;
                
            end
            
        else % new primary key
            
            count = count + 1;
            tcount = 1;
            
            % primarykey secondarykey tbyte(trace byte location in file)
            % skeymax skeyinc tkey  (initialize the last 3 values
            % to 1
            compress_offset_bytes(count,:) = [ pkey skey tbyte 1 1 1];
            pkey_prev = pkey;
            skey_prev = skey;

        end
        
    end
    
    
    compressed_lookup = compress_offset_bytes; 
end

function compressed_lookup = compress_skeys(compress_offset_bytes)
%% Function Definition
% Compresses secondary lookup information by
% grouping adjacent skeys with the same increment and tertiary key fields.
%
%  Inputs:
%   compress_offset_bytes [pkey skey tbyte(byte location of trace)
%   1 skey_increment 1]
%
%  Outputs:
%    compressed_lookup [pkey skey tbyte(byte_location of trace)
%    maximum_skey skey_increment tertiary_key tkey_maximum
%    tkey_increment]
%%
    
    % These should be part of a strcuture definition somewhere
    pkey_loc = 1; % column numbers needs to be implemented
    skey_loc = 2;
    byte_loc = 3;
    tkey_loc = 4;
 
    
    % Get the compressed size of the block
    blocktr = size(compress_offset_bytes,1);
    
    if blocktr > 1
        start_idx = 1;
        count = 0;
        row_i = 1;

        %TODO This is weird. Fix up with something more legitimate
        pkey_prev = -995837;
        skey_prev = -9999437;
        skey_inc = -999971;
        cur_inc = -27389995;
        tkey_min_prev = -999971;
        tkey_max_prev = 999971;
        tkey_inc_prev = 999971;
        tkey_inc_prev = -27389995;

        
        for row_i = start_idx:blocktr
            
            pkey = compress_offset_bytes(row_i,pkey_loc);
            skey = compress_offset_bytes(row_i,skey_loc);
            tbyte = compress_offset_bytes(row_i,byte_loc);
            
            tkey_min = compress_offset_bytes(row_i,4); % 1
            tkey_max = compress_offset_bytes(row_i,5); % ntraces at
                                                       % pkey, skey
            tkey_inc = compress_offset_bytes(row_i,6); % 1
            
            
            % Checks if the tertiary keys are the same as the
            % previous lookup index
            if pkey == pkey_prev && tkey_min == tkey_min_prev && ...
                     tkey_max == tkey_max_prev && tkey_inc == tkey_inc_prev
                
                cur_inc = skey - skey_prev; 
                
                case true
                  
               
                  of (cur_inc ~= skey_inc) & cur_inc == 0 do
                  % Same secondary key as previous group (duplicate)
                    
                    % Make a new trace group
                    count = count + 1;
                    compress_ilxl_bytes(count,:) = ...
                        [ pkey skey tbyte skey 1 tkey_min tkey_max ...
                          tkey_inc];
                  
                    % reset increment
                    skey_inc = -999971; % flag duplicate
                    skey_prev = skey;
                  
                    tkey_min_prev = tkey_min;
                    tkey_max_prev = tkey_max;
                    tkey_inc_prev = tkey_inc;
                    
                    break;
                  
                  of (cur_inc ~= skey_inc) & cur_inc == -999971 do
                    % First trace in a new group or previous trace
                    % was a duplicate
                  
                    % Update the fields and move on
                    compress_ilxl_bytes(count,4:5) = [ skey cur_inc ];
                    skey_inc = cur_inc;
                    skey_prev = skey;
                            
                    tkey_min_prev = tkey_min;
                    tkey_max_prev = tkey_max;
                    tkey_inc_prev = tkey_inc;
                    
                  of (cur_inc ~= skey_inc)
                  % New trace grouping with different skey increments
                            
                    % Requires a new trace grouping
                    count = count + 1;
                    compress_ilxl_bytes(count,:) = [ pkey skey tbyte ...
                                        skey cur_inc tkey_min ...
                                        tkey_max tkey_inc];
                  
                    skey_inc = cur_inc;
                    skey_prev = skey;
                    tkey_min_prev = tkey_min;
                    tkey_max_prev = tkey_max;
                    tkey_inc_prev = tkey_inc;
                            
                    break;
                    
                otherwise
                % Compressible skey, add it to the group    
                  
                    % Update the maximum skey
                    compress_ilxl_bytes(count,4) = skey;
                    skey_prev = skey;
                    
                    
                    tkey_min_prev = tkey_min;
                    tkey_max_prev = tkey_max;
                    tkey_inc_prev = tkey_inc;
                    
                end_case
                
                
            else % New primary key or different set of teriary keys
                
                % new lookup group
                count = count + 1;
                compress_ilxl_bytes(count,:) = [ pkey skey tbyte ...
                                    skey 1 tkey_min tkey_max tkey_inc];
                
                pkey_prev = pkey;
                skey_prev = skey;
                tkey_min_prev = tkey_min;
                tkey_max_prev = tkey_max;
                tkey_inc_prev = tkey_inc;
                skey_inc = -999971;
                
            end
            
        end
        
    else % only one group
        
        count = count + 1;
        compress_ilxl_bytes(count,:) = [ compress_offset_bytes(row_i,pkey_loc)...
                            compress_offset_bytes(row_i,skey_loc) ...
                            compress_offset_bytes(row_i,byte_loc) ...
                            compress_offset_bytes(row_i,skey_loc) ...
                            1 compress_offset_bytes(row_i,4) ...
                            compress_offset_bytes(row_i,5) ...
                            compress_offset_bytes(row_i,6)];
    end
end
    